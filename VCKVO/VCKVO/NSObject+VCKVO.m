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

static NSString * getterNameFromSetter(NSString *setterName) {
	return [NSString stringWithFormat:@"%@%@", [setterName substringWithRange:NSMakeRange(3, 1)].lowercaseString, [setterName substringWithRange:NSMakeRange(4, setterName.length - 5)]];
}

// FIXME: arm64的va_list的结构改变，会crash：https://blog.nelhage.com/2010/10/amd64-and-va_arg/
// 动态参数是因为：指针类型id和值类型如int不兼容
static void VCSetter(id self, SEL _cmd, ...)   {
	NSString *setterName = NSStringFromSelector(_cmd);
	NSString *getterName = getterNameFromSetter(setterName);
	Class inerClass = object_getClass(self);
	
	// 获取参数的类型
	NSMethodSignature *methodSignature = [inerClass instanceMethodSignatureForSelector:_cmd];
	const char *argumentType = [methodSignature getArgumentTypeAtIndex:2];
	
	id obj;
	va_list args;
	va_start(args, _cmd);
	switch (argumentType[0]) {
		case 'c':
			obj = @(va_arg(args, char));
			break;
		case 'i':
			obj = @(va_arg(args, int));
			break;
		case 's':
			obj = @(va_arg(args, short));
			break;
		case 'l':
			obj = @(va_arg(args, long));
			break;
		case 'q':
			obj = @(va_arg(args, long long));
			break;
		case 'C':
			obj = @(va_arg(args, unsigned char));
			break;
		case 'I':
			obj = @(va_arg(args, unsigned int));
			break;
		case 'S':
			obj = @(va_arg(args, unsigned short));
			break;
		case 'L':
			obj= @(va_arg(args, unsigned long));
			break;
		case 'Q':
			obj = @(va_arg(args, unsigned long long));
			break;
		case 'f':
			obj = @(va_arg(args, float));
			break;
		case 'd':
			obj = @(va_arg(args, double));
			break;
		case 'B':
			obj = @(va_arg(args, BOOL));
		default:
			obj = (va_arg(args, id));
			break;
	}
	va_end(args);
	
	// 调用父类的setter方法
	Class originalClass = class_getSuperclass(inerClass);
	struct objc_super superInfo = {
		self,
		originalClass
	};
	((void (*) (void * , SEL, ...))objc_msgSendSuper)(&superInfo, _cmd, obj);
	
	// 获取观察者
	NSMapTable * observerMap = objc_getAssociatedObject(self, _observer);
	id observer = [observerMap objectForKey: getterName];
	SEL sel = NSSelectorFromString(@"vc_observeValueForKeyPath:ofObject:change:");
	if (observer) {
		if([observer respondsToSelector:sel]) {
			// objc_msgSend方法来调用vc_observeValueForKeyPath:ofObject:change:方法
			((void(*) (id, SEL, ...))objc_msgSend)(observer, sel, getterName, self, obj);
		}
	}
}

static id getArgument(NSInvocation *invocation){
	id value;
	if (invocation.methodSignature.numberOfArguments>2) {
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
static void swizzlingForwardInvocation(Class _Nonnull class) {
	SEL forwardInvocationSelector = NSSelectorFromString(@"forwardInvocation:");
	Method forwardInvocationMethod = class_getInstanceMethod(class, forwardInvocationSelector);
	const char *orginalEncodingTypes = method_getTypeEncoding(forwardInvocationMethod);
	void (*originalForwardInvocationImp)(id, SEL, NSInvocation *) = (void *)method_getImplementation(forwardInvocationMethod);
	
	id vcForwardInvocationImp = ^(id self, NSInvocation *invocation) {
		SEL selector = invocation.selector;
		NSString *setterName = NSStringFromSelector(selector);
		
		if(![setterName hasPrefix:@"set"]) {
			if(originalForwardInvocationImp) {
				originalForwardInvocationImp(self, selector, invocation);
			} else {
				[self doesNotRecognizeSelector:selector];
			}
			return;
		}
		
		id value = getArgument(invocation);
		
		struct objc_super superInfo = {
			self,
			class_getSuperclass(class)
		};
		// 调用父类的setter方法
		((void (*) (void * , SEL, ...))objc_msgSendSuper)(&superInfo, selector, value);

		// 获取观察者
		NSMapTable * observerMap = objc_getAssociatedObject(self, _observer);
		id observer = [observerMap objectForKey: getterNameFromSetter(setterName)];
		SEL observerSelector = NSSelectorFromString(@"vc_observeValueForKeyPath:ofObject:change:");
		if (observer) {
			if([observer respondsToSelector:observerSelector]) {
				// objc_msgSend方法来调用vc_observeValueForKeyPath:ofObject:change:方法
				((void(*) (id, SEL, ...))objc_msgSend)(observer, observerSelector, getterNameFromSetter(setterName), self, value);
			}
		}
	};

	class_replaceMethod(class, forwardInvocationSelector, imp_implementationWithBlock(vcForwardInvocationImp), orginalEncodingTypes);
	imp_removeBlock(imp_implementationWithBlock(vcForwardInvocationImp));
}


- (void)vc_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
	// FIXME: 未考虑链式keyValue情况，如：person.car.price
	
	/** isa swizzling
	  * 1. 判断当前类的类型，以及中间类是否已经存在。如果既不是中间类，中间类也不存在，创建集成自原类的中间类
	  * 2. 根据keyPath拼接成setter样式的selector，根据selector获取原setter参数类型并为中间类动态添加新方法
	  * 3. 将self实例的isa指向中间类
	**/
	Class originalClass = object_getClass(self);
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

	NSString *setterSel = [NSString stringWithFormat:@"set%@%@:", [keyPath substringToIndex:1].uppercaseString, [keyPath substringFromIndex:1] ];
	
	// 获取入参方法类型
	Method method = class_getInstanceMethod(originalClass, NSSelectorFromString(setterSel));
	const char *types = method_getTypeEncoding(method);
	
//	class_addMethod(inerClass, NSSelectorFromString(setterSel), (IMP)VCSetter, types);

	/** Method swizzling -- 解决VCSetter对于arm 64支持不足的问题
	 * 1. 用vcForwardInvocation替换forwardInvocation的实现
	 * 2. 将setter的selector指向完整消息转发方法forwardInvocation，用以传输不明确是指针类型还是值类型的参数
	 **/
	swizzlingForwardInvocation(inerClass);
	class_replaceMethod(inerClass, NSSelectorFromString(setterSel), _objc_msgForward, types);
	
	NSMapTable<NSString *, id> *map = objc_getAssociatedObject(self, _observer);
	if(!map) {
		map = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory];
	}
	[map setObject:observer forKey:keyPath];
	
	// 动态将observer添加到instance
//	objc_setAssociatedObject(self, _observer, observer, OBJC_ASSOCIATION_ASSIGN);
	objc_setAssociatedObject(self, _observer, map, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	// 把instance的isa指向inerClass
	object_setClass(self, inerClass);
}

- (void)vc_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
	Class currentClass = object_getClass(self);
	NSMapTable *map = objc_getAssociatedObject(self, _observer);
	[map removeObjectForKey: keyPath];
	if([NSStringFromClass(currentClass) hasPrefix: prefix] && map.count <= 0) {
		Class superClass = class_getSuperclass(currentClass);
		object_setClass(self, superClass);
//		objc_removeAssociatedObjects(self);
//		objc_disposeClassPair(currentClass);
	}
}

@end
