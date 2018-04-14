//
//  ViewController.m
//  VCKVO
//
//  Created by ZHANG Zhipeng on 2018/4/11.
//  Copyright © 2018年 zzp. All rights reserved.
//

#import "ViewController.h"
#import "NSObject+VCKVO.h"

@interface Person: NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *nickName;
@property (nonatomic, assign) NSInteger age;
@property (nonatomic, assign) double salary;

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
	NSLog(@"=== person1 ===");
	Person *person = [[Person alloc] initWithName:@"Vincent"];
	[person vc_addObserver:self forKeyPath:@"nickName"];
	person.nickName = @"Joker";
	
	NSLog(@"=== person2 ===");
	Person *person2 = [[Person alloc] initWithName:@"vc"];
	[person2 vc_addObserver:self forKeyPath:@"name"];
	person2.name = @"James";
	[person2 vc_addObserver:self forKeyPath:@"nickName"];
	[person2 vc_addObserver:self forKeyPath:@"age"];
	[person2 vc_addObserver:self forKeyPath:@"salary"];
	person2.nickName = @"kc";
	person2.age = 10;
	person2.salary = 1000.0;
	[person2 vc_removeObserver:self forKeyPath:@"nickName"];
	NSLog(@"=== after remove p2 nickName observer ===");
	person2.nickName = @"Pogba";
	person2.name = @"Ronaldo";
	
	NSLog(@"=== after remove p1 name observer ===");
	[person vc_removeObserver:self forKeyPath:@"nickName"];
	person.nickName = @"Alex";
}

- (void)vc_observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(id)change {
	NSLog(@"=== vc_observeValueForKeyPath ===");
	NSLog(@"< object = %@, keyPath = %@, change = %@ >",object, keyPath, change);
}



- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}


@end
