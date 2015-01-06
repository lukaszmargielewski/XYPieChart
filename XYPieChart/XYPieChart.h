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

@class XYPieChart;
@class SliceLayer;

@interface CARadialGradientRenderer : NSObject

@property (nonatomic, weak)     XYPieChart *pieChart;
@property (nonatomic, weak)     SliceLayer *sliceLayer;

-(void)renderpieChart:(XYPieChart *)pieChart inLayer:(CALayer *)layer;

@end


@interface SliceLayer : CAShapeLayer

@property (nonatomic, assign) CGFloat   value;
@property (nonatomic, assign) CGFloat   percentage;
@property (nonatomic, assign) double    startAngle;
@property (nonatomic, assign) double    endAngle;
@property (nonatomic, assign) BOOL      isSelected;
@property (nonatomic, strong) NSString  *text;

@property (nonatomic, strong) CALayer *backgroundLayer;
@property (nonatomic, strong) CARadialGradientRenderer *backgroundRenderer;

@end

static CGMutablePathRef CGPathCreateArc(CGPoint center, CGFloat radius, CGFloat width, CGFloat startAngle, CGFloat endAngle){
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGFloat radiusOuter = radius;
    CGFloat radiusInner = radius - width;
    
    CGPathAddArc(path, NULL, center.x, center.y, radiusOuter, endAngle, startAngle, YES);
    CGPathAddArc(path, NULL, center.x, center.y, radiusInner, startAngle, endAngle, NO);
    
    CGPathCloseSubpath(path);
    
    return path;
}


@protocol XYPieChartDataSource <NSObject>
@required
- (NSUInteger)numberOfSlicesInPieChart:(XYPieChart *)pieChart;
- (CGFloat)pieChart:(XYPieChart *)pieChart valueForSliceAtIndex:(NSUInteger)index;

@optional
- (UIColor *)pieChart:(XYPieChart *)pieChart colorForSliceAtIndex:(NSUInteger)index;
- (NSString *)pieChart:(XYPieChart *)pieChart textForSliceAtIndex:(NSUInteger)index;
-(dispatch_queue_t)renderQueueForPieChart:(XYPieChart *)pieChart;

@end

@protocol XYPieChartDelegate <NSObject>
@optional
- (void)pieChart:(XYPieChart *)pieChart willSelectSliceAtIndex:(NSUInteger)index;
- (void)pieChart:(XYPieChart *)pieChart didSelectSliceAtIndex:(NSUInteger)index;
- (void)pieChart:(XYPieChart *)pieChart willDeselectSliceAtIndex:(NSUInteger)index;
- (void)pieChart:(XYPieChart *)pieChart didDeselectSliceAtIndex:(NSUInteger)index;
@end

@interface XYPieChart : UIView

@property(nonatomic, weak) id<XYPieChartDataSource> dataSource;
@property(nonatomic, weak) id<XYPieChartDelegate> delegate;
@property(nonatomic, assign) CGFloat startPieAngle;
@property(nonatomic, assign) CGFloat animationSpeed;
@property(nonatomic, assign) CGPoint pieCenter;
@property(nonatomic, assign) CGFloat pieRadius;
@property(nonatomic, assign) CGFloat pieAnlgeStep;
@property(nonatomic, assign) CGFloat pieSteps;
@property(nonatomic, assign) CGFloat pieWidth;
@property(nonatomic, assign) CGFloat pieCenterPadding;
@property(nonatomic, assign) BOOL    showLabel;
@property(nonatomic, strong) UIFont  *labelFont;
@property(nonatomic, strong) UIColor *labelColor;
@property(nonatomic, strong) UIColor *labelShadowColor;
@property(nonatomic, assign) CGFloat labelRadius;
@property(nonatomic, assign) CGFloat selectedSliceStroke;
@property(nonatomic, assign) CGFloat selectedSliceOffsetRadius;
@property(nonatomic, assign) BOOL    showPercentage;

@property (nonatomic, readonly) CGSize centerSugestedSize;

@property (nonatomic, readonly) CATextLayer *centerValueTitleLayer;
@property (nonatomic, readonly) CATextLayer *centerValueSubtitleLayer;
@property (nonatomic, readonly) CALayer *centerBackgroundLayer;
@property (nonatomic, readonly) CALayer *centerContentLayer;
@property (nonatomic, readonly) UIView *pieView;
@property (nonatomic, strong) NSString *name;

- (void)reloadData;
- (void)setPieBackgroundColor:(UIColor *)color;
- (void)clear;
- (void)setSliceSelectedAtIndex:(NSInteger)index;
- (void)setSliceDeselectedAtIndex:(NSInteger)index;


@end;
