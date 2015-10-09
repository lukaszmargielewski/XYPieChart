//
//  XYPieChart.h
//  XYPieChart
//
//  Created by XY Feng on 2/24/12.
//  Copyright (c) 2012 Xiaoyang Feng. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>


static CGMutablePathRef CGPathCreateArc(CGPoint center, CGFloat radius, CGFloat width, CGFloat startAngle, CGFloat endAngle){
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGFloat radiusOuter = radius;
    CGFloat radiusInner = radius - width;
    
    CGPathAddArc(path, NULL, center.x, center.y, radiusOuter, endAngle, startAngle, YES);
    CGPathAddArc(path, NULL, center.x, center.y, radiusInner, startAngle, endAngle, NO);
    
    CGPathCloseSubpath(path);
    
    return path;
}

@class XYPieChart;

@protocol XYPieChartDataSource <NSObject>

@required

- (NSUInteger)numberOfSlicesInPieChart:(XYPieChart *)pieChart;
- (CGFloat)pieChart:(XYPieChart *)pieChart valueForSliceAtIndex:(NSUInteger)index;
- (UIColor *)pieChart:(XYPieChart *)pieChart colorForSliceAtIndex:(NSUInteger)index;

@optional

- (dispatch_queue_t)renderQueueForPieChart:(XYPieChart *)pieChart;

@end

@interface XYPieChart : UIView

@property(nonatomic, weak) id<XYPieChartDataSource> dataSource;

// Properties not affecting layout:
@property(nonatomic, assign) CGFloat startPieAngle              UI_APPEARANCE_SELECTOR;
@property(nonatomic, assign) CGFloat pieAnlgeStep               UI_APPEARANCE_SELECTOR;
@property(nonatomic, assign) CGFloat pieSteps                   UI_APPEARANCE_SELECTOR;
@property(nonatomic, assign) CGFloat valueSeparatorLineWidth    UI_APPEARANCE_SELECTOR;

@property(nonatomic, assign) int    gradientFill                UI_APPEARANCE_SELECTOR;
@property(nonatomic, assign) int    showsPieSteps               UI_APPEARANCE_SELECTOR;


// Properties affecting layout:
@property(nonatomic, assign) CGFloat pieRadius UI_APPEARANCE_SELECTOR;
@property(nonatomic, assign) CGFloat pieWidth UI_APPEARANCE_SELECTOR;
@property(nonatomic, assign) CGFloat pieCenterPadding UI_APPEARANCE_SELECTOR;

// Read only properties:
@property (nonatomic, readonly) CGSize centerSugestedSize;
@property (nonatomic, readonly) CALayer *centerBackgroundLayer;
@property (nonatomic, readonly) CALayer *centerContentLayer;
@property (nonatomic, readonly) CALayer *pieLayer;


// Public API:
- (void)reloadData;
- (void)setPieBackgroundColor:(UIColor *)color;
- (void)clear;

@end;
