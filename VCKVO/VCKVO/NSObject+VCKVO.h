//
//  NSObject+VCKVO.h
//  VCKVO
//
//  Created by ZHANG Zhipeng on 2018/4/11.
//  Copyright © 2018年 zzp. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (VCKVO)
- (void)vc_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath;
- (void)vc_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath;
@end
