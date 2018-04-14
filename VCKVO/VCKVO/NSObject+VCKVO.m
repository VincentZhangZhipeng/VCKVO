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

// FIXME: arm64的va_list 的结构改变，会crash：https://blog.nelhage.com/2010/10/amd64-and-va_arg/
// 动态参数是因为：指针类型id和值类型如int不兼容
static void VCSetter(id self, SEL _cmd, ...)   {
	NSString *setterName = NSStringFromSelector(_cmd);
	NSString *getterName = [NSString stringWithFormat:@"%@%@", [setterName substringWithRange:NSMakeRange(3, 1)].lowercaseString, [setterName substringWithRange:NSMakeRange(4, setterName.length - 5)]];
	Class inerClass = object_getClass(self);
	Class originalClass = class_getSuperclass(inerClass);
	struct objc_super superInfo = {
		self,
		originalClass
	};
	
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


- (void)vc_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
	// FIXME: 未考虑链式keyValue情况，如：person.car.price
	
	/** isa swizzling
	  * 1. 判断当前类的类型，以及中间类是否已经存在。如果既不是中间类，中间类也不存在，创建中间类
	  * 2. 根据keyPath拼接成setter样式的selector，selector
	  * 3. 根据
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
	
	class_addMethod(inerClass, NSSelectorFromString(setterSel), (IMP)VCSetter, types);
	
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
		objc_removeAssociatedObjects(self);
	}
}
@end
