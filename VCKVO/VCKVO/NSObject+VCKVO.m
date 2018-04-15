//
//  NSObject+VCKVO.m
//  VCKVO
//
//  Created by ZHANG Zhipeng on 2018/4/11.
//  Copyright © 2018年 zzp. All rights reserved.
//

#import "NSObject+VCKVO.h"
#import <objc/runtime.h>
#import <objc/message.h>

NSString * const prefix = @"VCNSNotify_";
const void* _observer  = &_observer;

@implementation NSObject (VCKVO)

#pragma mark - c methods
static NSString * getterNameFromSetter(NSString *setterName) {
	return [NSString stringWithFormat:@"%@%@", [setterName substringWithRange:NSMakeRange(3, 1)].lowercaseString, [setterName substringWithRange:NSMakeRange(4, setterName.length - 5)]];
}

static id getArgument(NSInvocation *invocation){
	id value;
	if (invocation.methodSignature.numberOfArguments > 2) {
#define getValue(type) \
type arg;\
[invocation getArgument:&arg atIndex:2];\
value = @(arg);\

		switch ([invocation.methodSignature getArgumentTypeAtIndex:2][0]) {
			case 'c':
			{
				getValue(char)
				break;
			}
			case 'i':
			{
				getValue(int)
				break;
			}
			case 's':
			{
				getValue(short)
				break;
			}
			case 'l':
			{
				getValue(long)
				break;
			}
			case 'q':
			{
				getValue(long long)
				break;
			}
			case 'C':
			{
				getValue(unsigned char)
				break;
			}
			case 'I':
			{
				getValue(unsigned int)
			}	break;
			case 'S':
			{
				getValue(unsigned short)
			}	break;
			case 'L':
			{
				getValue(unsigned long)
			}	break;
			case 'Q':
			{
				getValue(unsigned long long)
			}	break;
			case 'f':
			{
				getValue(float)
			}	break;
			case 'd':
			{
				getValue(double)
			}	break;
			case 'B':
			{
				getValue(BOOL)
				break;
			}
			default:
				[invocation getArgument:&value atIndex:2];
				break;
		}
	}
	return value;
}

// 混淆forwardInvocation方法
static void swizzleForwardInvocation(Class _Nonnull class) {
	SEL forwardInvocationSelector = NSSelectorFromString(@"forwardInvocation:");
	Method forwardInvocationMethod = class_getInstanceMethod(class, forwardInvocationSelector);
	const char *orginalEncodingTypes = method_getTypeEncoding(forwardInvocationMethod);
	void (*originalForwardInvocationImp)(id, SEL, NSInvocation *) = (void *)method_getImplementation(forwardInvocationMethod);
	
	id vcForwardInvocationImp = ^(id target, NSInvocation *invocation) {
		SEL selector = invocation.selector;
		NSString *setterName = NSStringFromSelector(selector);
		
		if(![setterName hasPrefix:@"set"]) {
			if(originalForwardInvocationImp) {
				originalForwardInvocationImp(target, selector, invocation);
			} else {
				[target doesNotRecognizeSelector:selector];
			}
			return;
		}
		
		id value = getArgument(invocation);
		
		struct objc_super superInfo = {
			target,
			class_getSuperclass(class)
		};
		// 调用父类的setter方法
		((void (*) (void * , SEL, ...))objc_msgSendSuper)(&superInfo, selector, value);

		// 获取观察者
		NSMapTable * observerMap = objc_getAssociatedObject(target, _observer);
		id observer = [observerMap objectForKey: getterNameFromSetter(setterName)];
		SEL observerSelector = NSSelectorFromString(@"vc_observeValueForKeyPath:ofObject:change:");
		if (observer) {
			if([observer respondsToSelector:observerSelector]) {
				// objc_msgSend方法来调用vc_observeValueForKeyPath:ofObject:change:方法
				((void(*) (id, SEL, ...))objc_msgSend)(observer, observerSelector, getterNameFromSetter(setterName), target, value);
			}
		}
	};

	class_replaceMethod(class, forwardInvocationSelector, imp_implementationWithBlock(vcForwardInvocationImp), orginalEncodingTypes);
	imp_removeBlock(imp_implementationWithBlock(vcForwardInvocationImp));
}

static void vcCreateInerClass(id target, NSObject * observer, NSString* getterName) {
	/** isa swizzling
	 * 1. 判断当前类的类型，以及中间类是否已经存在。如果既不是中间类，中间类也不存在，创建集成自原类的中间类
	 * 2. 根据keyPath拼接成setter样式的selector，根据selector获取原setter参数类型并为中间类动态添加新方法
	 * 3. 将self实例的isa指向中间类
	 **/
	Class originalClass = object_getClass(target);
	Class inerClass;
	if ([NSStringFromClass(originalClass) hasPrefix: prefix]) {
		inerClass = originalClass;
	} else if(NSClassFromString([prefix stringByAppendingString:NSStringFromClass(originalClass)])) {
		inerClass = NSClassFromString([prefix stringByAppendingString:NSStringFromClass(originalClass)]);
	} else {
		const char* inerClassName = [NSString stringWithFormat:@"%@%@", prefix, NSStringFromClass(originalClass)].UTF8String;
		inerClass = objc_allocateClassPair(originalClass, inerClassName, 0);
		// 注册class，注意未注销前只能注册一次
		objc_registerClassPair(inerClass);
	}
	
	NSString *setterSel = [NSString stringWithFormat:@"set%@%@:", [getterName substringToIndex:1].uppercaseString, [getterName substringFromIndex:1] ];
	
	// 获取入参方法类型
	Method method = class_getInstanceMethod(originalClass, NSSelectorFromString(setterSel));
	const char *types = method_getTypeEncoding(method);
	
	/** Method swizzling -- 解决VCSetter对于arm 64支持不足的问题
	 * 1. 用vcForwardInvocation替换forwardInvocation的实现
	 * 2. 将setter的selector指向完整消息转发方法forwardInvocation，用以传输不明确是指针类型还是值类型的参数
	 **/
	swizzleForwardInvocation(inerClass);
	class_replaceMethod(inerClass, NSSelectorFromString(setterSel), _objc_msgForward, types);
	
	NSMapTable<NSString *, id> *map = objc_getAssociatedObject(target, _observer);
	if(!map) {
		map = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory];
	}
	[map setObject:observer forKey:getterName];
	
	// 动态将observer添加到instance
	objc_setAssociatedObject(target, _observer, map, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	// 把instance的isa指向inerClass
	object_setClass(target, inerClass);
}

- (id)targetFromKeyPath:(NSString *)keyPath {
	id target = self;
	NSArray *keyPaths = [keyPath componentsSeparatedByString:@"."];
	if (keyPaths.count > 1) {
		// 根据链式keyPath遍历获取getter对应的classclass
		for (int i=0; i<keyPaths.count-1; i++) {
			target = [target valueForKey: [keyPaths objectAtIndex:i]];
		}
	}
	return target;
}

#pragma mark - kvo methods
- (void)vc_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
	id target = [self targetFromKeyPath:keyPath];
	NSString *getterName = [[keyPath componentsSeparatedByString:@"."] lastObject];
	vcCreateInerClass(target, observer, getterName);
}

- (void)vc_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
	id target = [self targetFromKeyPath:keyPath];
	Class currentClass = object_getClass(target);
	NSMapTable *map = objc_getAssociatedObject(target, _observer);
	[map removeObjectForKey: [[keyPath componentsSeparatedByString:@"."] lastObject]];
	
	if([NSStringFromClass(currentClass) hasPrefix: prefix] && map.count <= 0) {
		// 重新指向未添加中间类之前的类
		Class superClass = class_getSuperclass(currentClass);
		object_setClass(target, superClass);
	}
}

- (void)vc_observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(id)change {
	NSLog(@"=== NSObject vc_observeValueForKeyPath ===");
	NSLog(@"< object = %@, keyPath = %@, change = %@ >",object, keyPath, change);
}

@end
