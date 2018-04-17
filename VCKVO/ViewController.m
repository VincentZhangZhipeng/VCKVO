//
//  ViewController.m
//  VCKVO
//
//  Created by ZHANG Zhipeng on 2018/4/11.
//  Copyright © 2018年 zzp. All rights reserved.
//

#import "ViewController.h"
#import "NSObject+VCKVO.h"
#import <objc/runtime.h>

@interface Wheel: NSObject
@property (nonatomic, assign) float price;
@end

@implementation Wheel
@end

@interface Car: NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) Wheel *wheel;
@end

@implementation Car
@end

@interface Person: NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *nickName;
@property (nonatomic, assign) NSInteger age;
@property (nonatomic, assign) float salary;
@property (nonatomic, strong) Car *car;

- (id) initWithName:(NSString *)name;
@end

@implementation Person
- (id) initWithName:(NSString *)name {
	if (self = [super init]) {
		_name = name;
	}
	return self;
}
@end

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	
	// 观察kvo添加前后的person类
//	[self kvoInsight];
	
	[self person1Handling];
	[self person2Handling];
	
}

- (void)kvoInsight {
	Person *person = [Person new];
	NSLog(@"person isa is <%@: %p>", object_getClass(person) , object_getClass(person));
	NSLog(@"====== after add kvo ======");
	[person addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
	NSLog(@"person isa is <%@: %p>", object_getClass(person), object_getClass(person));
	NSLog(@"====== after remove kvo ======");
	[person removeObserver:self forKeyPath:@"name" context:nil];
	NSLog(@"person isa is <%@: %p>", object_getClass(person), object_getClass(person));
}

- (void)person1Handling {
	NSLog(@"===== person1 =====");
	Person *person = [[Person alloc] initWithName:@"Vincent"];
	person.car = [[Car alloc] init];
	person.car.wheel = [Wheel new];
	[person vc_addObserver:self forKeyPath:@"car.name"];
	[person vc_addObserver:person.car forKeyPath:@"car.wheel.price"];
	person.car.name = @"Benz";
	person.car.wheel.price = 100.5;
	
	
	NSLog(@"=== after remove p1 observers ===");
	[person vc_removeObserver:person.car forKeyPath:@"car.wheel.price"];
	[person vc_removeObserver:self forKeyPath:@"car.name"];
	person.car.name = @"BMW";
	person.car.wheel.price = 101.5;
	[person vc_addObserver:self forKeyPath:@"age"];
	person.age = 1;
}

- (void)person2Handling {
	NSLog(@"===== person2 =====");
	Person *person2 = [[Person alloc] initWithName:@"vc"];
	[person2 vc_addObserver:self forKeyPath:@"name"];
	person2.name = @"James";
	[person2 vc_addObserver:self forKeyPath:@"nickName"];
	[person2 vc_addObserver:self forKeyPath:@"age"];
	[person2 vc_addObserver:self forKeyPath:@"salary"];
	person2.nickName = @"kc";
	person2.age = 10;
	person2.salary = 1000.1;
	[person2 vc_removeObserver:self forKeyPath:@"nickName"];
	NSLog(@"=== after remove p2 nickName observer ===");
	person2.nickName = @"Pogba";
	person2.name = @"Ronaldo";
	
}

- (void)vc_observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(id)change {
	NSLog(@"=== ViewController vc_observeValueForKeyPath ===");
	NSLog(@"< object = %@, keyPath = %@, change = %@ >",object, keyPath, change);
}


- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}


@end
