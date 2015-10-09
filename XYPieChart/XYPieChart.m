#import "XYPieChart.h"
#import <QuartzCore/QuartzCore.h>


@implementation XYPieChart
{
    
    CGRect _pieOuterFrame;
    CGRect _pieInnerFrame;
    
    CGSize _renderPieSize;
    CGPoint _renderCenter;
    
}

@synthesize centerSugestedSize = _centerSugestedSize;
@synthesize pieLayer = _pieLayer;
@synthesize centerBackgroundLayer = _centerBackgroundLayer;
@synthesize centerContentLayer = _centerContentLayer;

-(id)initWithCoder:(NSCoder *)aDecoder{

    self = [super initWithCoder:aDecoder];
    
    if (self) {
        [self commonInit];
    }
    return self;
}
- (id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self)
    {
        
        [self commonInit];
    }
    return self;
}
-(void)commonInit{
    
    self.backgroundColor = [UIColor clearColor];
    _pieLayer = [CALayer layer];
    _pieLayer.contentsGravity = kCAGravityCenter;
    
    CGFloat scale = [[UIScreen mainScreen] scale];
    
    _centerBackgroundLayer = [CALayer layer];
    _centerBackgroundLayer.contentsGravity = kCAGravityResizeAspect;
    
    _centerContentLayer = [CALayer layer];
    _centerContentLayer.contentsGravity = kCAGravityCenter;
    _centerContentLayer.masksToBounds = YES;
    
    _pieLayer.contentsScale =
    _centerBackgroundLayer.contentsScale =
    _centerContentLayer.contentsScale = scale;
    [_centerBackgroundLayer addSublayer:_centerContentLayer];
    
    [self.layer addSublayer:_centerBackgroundLayer];
    [self.layer addSublayer:_pieLayer];
    
    CGRect frame = self.frame;
    _pieRadius = MIN(CGRectGetWidth(frame), CGRectGetHeight(frame)) / 2.0;
    [self recalculateLayoutWithReload:NO];
    
}
- (void)setFrame:(CGRect)frame{

    [super setFrame:frame];
    
    if (_pieRadius == 0) {
       _pieRadius = MIN(CGRectGetWidth(frame), CGRectGetHeight(frame)) / 2.0;
    }
    
    [self recalculateLayoutWithReload:NO];
}
- (void)recalculateLayoutWithReload:(BOOL)reload{

    CGFloat W = CGRectGetWidth(self.bounds);
    
    CGFloat wOuter = (_pieRadius) * 2.0;
    CGFloat xOuter = (W - wOuter) / 2.0;
    
    CGFloat radiusInner = _pieRadius - (_pieCenterPadding + _pieWidth);
    
    
    CGFloat wInner = (radiusInner) * 2.0;
    CGFloat xInner = (W - wInner) / 2.0;
    
    _pieOuterFrame = CGRectIntegral(CGRectMake(xOuter, xOuter, wOuter, wOuter));
    _pieInnerFrame = CGRectIntegral(CGRectMake(xInner, xInner, wInner, wInner));
    
    _renderPieSize = _pieOuterFrame.size;
    CGFloat w = _renderPieSize.width;
    CGFloat w2 = w / 2.0;
    _renderCenter = CGPointMake(w2, w2);
    
    
    CGFloat pieSize     = wOuter / sqrt(2.0f);
    _centerSugestedSize = CGSizeMake(pieSize, pieSize);
                                         
    [_pieLayer setFrame:_pieOuterFrame];
    [_pieLayer setCornerRadius:_pieRadius];
    
    _centerBackgroundLayer.frame = _pieInnerFrame;
    _centerContentLayer.frame = _centerBackgroundLayer.bounds;
    
    _centerBackgroundLayer.cornerRadius =
    _centerContentLayer.cornerRadius = wInner/2;
    
    /*
#ifdef DEBUG
    self.layer.borderWidth =
    _centerContentLayer.borderWidth =
    _centerBackgroundLayer.borderWidth =
    _pieLayer.borderWidth = 1;
    
    _pieLayer.borderColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:0.5].CGColor;
    _centerContentLayer.borderColor = [UIColor colorWithRed:0 green:1 blue:0 alpha:0.5].CGColor;
    _centerBackgroundLayer.borderColor = [UIColor colorWithRed:0 green:0 blue:1 alpha:0.5].CGColor;
    
#endif
    */
    
    
    if (reload) {
    
        [self reloadData];
    }
    
    
}

- (void)setPieRadius:(CGFloat)pieRadius{
    
    _pieRadius = pieRadius;
    [self setNeedsLayout];
}
                                         
- (void)setPieWidth:(CGFloat)pieWidth{
    
    _pieWidth = pieWidth;
    [self setNeedsLayout];
}

- (void)setPieCenterPadding:(CGFloat)pieCenterPadding{

    _pieCenterPadding = pieCenterPadding;
    [self setNeedsLayout];
}

- (void)layoutSubviews{

    [super layoutSubviews];
    [self recalculateLayoutWithReload:YES];
}
- (void)setPieBackgroundColor:(UIColor *)color{

    [_pieLayer setBackgroundColor:color.CGColor];
}



#pragma mark - manage settings

-(void)setPieAnlgeStep:(CGFloat)pieAnlgeStep{

    _pieAnlgeStep = pieAnlgeStep;
    
    if (_pieAnlgeStep) {
        _pieSteps = 0;
    }
}
-(void)setPieSteps:(CGFloat)pieSteps{

    _pieSteps = pieSteps;
    _pieAnlgeStep = (_pieSteps) ? (M_PI * 2.0) / _pieSteps : 0;
}


#pragma mark - Pie Reload Data With Animation

- (void)clear{

    CALayer *parentLayer = [self pieParentLayer];
    [CATransaction setDisableActions:YES];
    parentLayer.contents = nil;
    _centerContentLayer.contents = nil;
    [CATransaction commit];
}

- (void)reloadData{
    
    CALayer *parentLayer = [self pieParentLayer];
    
    
    if (_dataSource){
        
    
        // 3. Prepare graphics context:
        
        dispatch_queue_t queue = [_dataSource renderQueueForPieChart:self];
        
        dispatch_async(queue, ^{
            
            NSUInteger sliceCount = [_dataSource numberOfSlicesInPieChart:self];
            
            double sum = 0.0;
            
            double *values = malloc(sliceCount * sizeof(double));
            double *angles = malloc(sliceCount * sizeof(double));
            
            NSMutableArray *colors = [[NSMutableArray alloc] initWithCapacity:sliceCount];
            
            // 1. values and colors"
            for (int index = 0; index < sliceCount; index++) {
                
                
                UIColor *color = [_dataSource pieChart:self colorForSliceAtIndex:index];
                if (!color)
                    color = [UIColor clearColor];
                
                colors[index] = color;
                values[index] = [_dataSource pieChart:self valueForSliceAtIndex:index];
                sum += values[index];
            }
            
            
            // 2. Calculate angles from exisiting values:
            for (int index = 0; index < sliceCount; index++) {
                double div;
                if (sum == 0)
                    div = 0;
                else
                    div = values[index] / sum;
                angles[index] = M_PI * 2 * div;
            }
        
            
            UIGraphicsBeginImageContextWithOptions(_renderPieSize, NO, 0);
            
            CGContextRef ctx = UIGraphicsGetCurrentContext();
            // 4. Draw loop:
            double startFromAngle =_startPieAngle;
            
            for(int index = 0; index < sliceCount; index ++){
                
                double angle = angles[index];
                double endFromAngle = startFromAngle + angle;
                
                UIColor *color = colors[index];
                
                //DLog(@"chart: %i. pie: %i angle start: %.1f, angle end: %.1f color(%.2f, %.2f, %.2f, %.2f)", self.tag, index, startFromAngle, endFromAngle, [color red], [color green], [color blue], [color alpha]);
                
                [self renderPieInContext:ctx fromAngle:startFromAngle toAngleAngleEnd:endFromAngle withColor:color];
                
                startFromAngle = endFromAngle;
                
            }
        
        
        // Draw marks:
        if(_pieAnlgeStep && _showsPieSteps){
            
        
            CGFloat radius          = _pieRadius;
            CGFloat width           = _pieWidth;
            CGFloat radius_inner    = (radius - width);
            CGFloat angle_step      = _pieAnlgeStep;
            CGPoint center          = _renderCenter;
            
        CGContextSetStrokeColorWithColor(ctx, [UIColor clearColor].CGColor );
        CGContextSetBlendMode(ctx, kCGBlendModeClear);
    
        CGMutablePathRef pathMarks = CGPathCreateMutable();
        
        for (CGFloat angle = -M_PI_2; angle <= M_PI * 1.5; angle += angle_step) {
            
            CGFloat sina = sinf(angle);
            CGFloat cosa = cosf(angle);
            
            CGPoint pInner = CGPointMake(center.x + radius_inner    * cosa , center.y + radius_inner   * sina);
            CGPoint pOuter = CGPointMake(center.x + radius          * cosa , center.y + radius         * sina);
            
            CGPathMoveToPoint(pathMarks, NULL, pInner.x, pInner.y);
            CGPathAddLineToPoint(pathMarks, NULL, pOuter.x, pOuter.y);
        }
        
        CGContextSetLineWidth(ctx, 1.0);
        CGContextAddPath(ctx, pathMarks);
        CGContextStrokePath(ctx);
        CGPathRelease(pathMarks);
        }
        
        // End drawing marks...
        
            UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            dispatch_sync(dispatch_get_main_queue(), ^{
                
                [CATransaction setDisableActions:YES];
                parentLayer.contents = (id)image.CGImage;
                [CATransaction commit];
            });
            
            free(values);
            free(angles);

            
        });
        
        
        
    }
    

}

-(void)renderPieInContext:(CGContextRef)ctx
                fromAngle:(float)angleStart
          toAngleAngleEnd:(float)angleEnd
                withColor:(UIColor *)color{
    
    //DLog(@"Render background for piechart: %i slice at index: %i",pieChart.tag, index);
    
    CGFloat radius = _pieRadius;
    CGFloat width             = _pieWidth;
    CGFloat radius_inner      = (radius - width);
    CGPoint center          = _renderCenter;
    
    //DLog(@"Rendering for width: %.1f", width);
    CGPathRef path = CGPathCreateArc(center, radius, width, angleStart, angleEnd);
    
    CGContextSaveGState(ctx);
    
    CGContextAddPath(ctx, path);
    CGContextClip(ctx);
    
    

    if (!_gradientFill) {
    
        CGContextSetFillColorWithColor(ctx, color.CGColor);
        CGContextFillRect(ctx, CGRectMake(0, 0, radius * 2.0, radius * 2.0));
        
    }else{
    
    
        
        // Render a radial background
        // http://developer.apple.com/library/ios/#documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_shadings/dq_shadings.html
        
       const CGFloat *comps = CGColorGetComponents(color.CGColor);
        
        CGFloat red         = comps[0];
        CGFloat gre         = comps[1];
        CGFloat blu         = comps[2];
        
        CGFloat alpaStart    = comps[3];
        
        CGFloat alphaEnd     = alpaStart * 0.5;
        
        // Create the gradient's colours:
        size_t num_locations    = 3;
        CGFloat *locations      = malloc(sizeof(CGFloat) * num_locations);
        CGFloat *components     = malloc(sizeof(CGFloat) * num_locations * 4);
        
        locations[0] = 0.0;
        locations[1] = 0.5;
        locations[2]  = 1.0;
        
        components[0 + 0] = red;
        components[0 + 1] = gre;
        components[0 + 2] = blu;
        components[0 + 3] = alpaStart;
        
        components[4 + 0] = red;
        components[4 + 1] = gre;
        components[4 + 2] = blu;
        components[4 + 3] = alpaStart;
        
        components[8 + 0] = red;
        components[8 + 1] = gre;
        components[8 + 2] = blu;
        components[8 + 3] = alphaEnd;
        
        
        CGColorSpaceRef myColorspace = CGColorSpaceCreateDeviceRGB();
        CGGradientRef myGradient = CGGradientCreateWithColorComponents(myColorspace, components, locations, num_locations);
        
        // Normalise the 0-1 ranged inputs to the width of the image
        
        // Draw it!
        CGContextDrawRadialGradient (ctx, myGradient, center, radius_inner, center, radius, 0);//kCGGradientDrawsBeforeStartLocation
        
        
        // Clean up
        CGColorSpaceRelease(myColorspace); // Necessary?
        CGGradientRelease(myGradient); // Necessary?
        CGPathRelease(path);
        free(components);
        free(locations);
        
        
    }
    
    CGFloat angleDiff = ABS(angleEnd - angleStart);
    
    // Draw marks:
    if(_valueSeparatorLineWidth > 0 && angleDiff < M_PI * 2.0){
        
        
        CGFloat radius          = _pieRadius;
        CGFloat width           = _pieWidth;
        CGFloat radius_inner    = (radius - width);
        
        
        CGContextSetStrokeColorWithColor(ctx, [UIColor clearColor].CGColor );
        CGContextSetBlendMode(ctx, kCGBlendModeClear);
        
        CGMutablePathRef pathMarks = CGPathCreateMutable();
        
            
            CGFloat sina = sinf(angleStart);
            CGFloat cosa = cosf(angleStart);
            
            CGPoint pInner = CGPointMake(center.x + radius_inner    * cosa , center.y + radius_inner   * sina);
            CGPoint pOuter = CGPointMake(center.x + radius          * cosa , center.y + radius         * sina);
            
            CGPathMoveToPoint(pathMarks, NULL, pInner.x, pInner.y);
            CGPathAddLineToPoint(pathMarks, NULL, pOuter.x, pOuter.y);

        
        sina = sinf(angleEnd);
        cosa = cosf(angleEnd);
        
        pInner = CGPointMake(center.x + radius_inner    * cosa , center.y + radius_inner   * sina);
        pOuter = CGPointMake(center.x + radius          * cosa , center.y + radius         * sina);
        
        CGPathMoveToPoint(pathMarks, NULL, pInner.x, pInner.y);
        CGPathAddLineToPoint(pathMarks, NULL, pOuter.x, pOuter.y);

        
        CGContextSetLineWidth(ctx, _valueSeparatorLineWidth);
        CGContextAddPath(ctx, pathMarks);
        CGContextStrokePath(ctx);
        CGPathRelease(pathMarks);
    }

    
    
    CGContextRestoreGState(ctx);
    
}

#pragma mark - Pie Layer Creation Method:

-(CALayer *)pieParentLayer{return _pieLayer;}

@end