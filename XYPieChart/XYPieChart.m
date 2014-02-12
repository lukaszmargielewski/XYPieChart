
#import "XYPieChart.h"
#import <QuartzCore/QuartzCore.h>
#import "UIColor-Expanded.h"



@implementation SliceLayer
@synthesize text = _text;
@synthesize value = _value;
@synthesize percentage = _percentage;
@synthesize startAngle = _startAngle;
@synthesize endAngle = _endAngle;
@synthesize isSelected = _isSelected;
@synthesize backgroundRenderer = _backgroundRenderer;

- (NSString*)description{
    return [NSString stringWithFormat:@"value:%f, percentage:%0.0f, start:%f, end:%f", _value, _percentage, _startAngle/M_PI*180, _endAngle/M_PI*180];
}

+ (BOOL)needsDisplayForKey:(NSString *)key {
    if ([key isEqualToString:@"startAngle"] || [key isEqualToString:@"endAngle"]) {
        return YES;
    }
    else {
        return [super needsDisplayForKey:key];
    }
}
- (id)initWithLayer:(id)layer{
    if (self = [super initWithLayer:layer])
    {
        if ([layer isKindOfClass:[SliceLayer class]]) {
            self.startAngle = [(SliceLayer *)layer startAngle];
            self.endAngle = [(SliceLayer *)layer endAngle];
        }
    }
    return self;
}


-(void)setBackgroundRenderer:(CARadialGradientRenderer *)backgroundRenderer{

    _backgroundRenderer = backgroundRenderer;
    backgroundRenderer.sliceLayer = self;
    
}
@end

@interface XYPieChart (Private) 
- (void)updateTimerFired:(NSTimer *)timer;
- (SliceLayer *)createSliceLayerAtIndex:(NSUInteger)index;
- (CGSize)sizeThatFitsString:(NSString *)string;
- (void)notifyDelegateOfSelectionChangeFrom:(NSUInteger)previousSelection to:(NSUInteger)newSelection;
@end

@implementation XYPieChart
{

    UIView  *_pieView;
    CARadialGradientRenderer *_renderer;
    

}

static NSUInteger kDefaultSliceZOrder = 100;

@synthesize dataSource = _dataSource;
@synthesize delegate = _delegate;
@synthesize startPieAngle = _startPieAngle;
@synthesize animationSpeed = _animationSpeed;
@synthesize pieCenter = _pieCenter;
@synthesize pieRadius = _pieRadius;
@synthesize pieRadiusInner = _pieRadiusInner;
@synthesize pieAnlgeStep = _pieAnlgeStep;
@synthesize showLabel = _showLabel;
@synthesize labelFont = _labelFont;
@synthesize labelColor = _labelColor;
@synthesize labelShadowColor = _labelShadowColor;
@synthesize labelRadius = _labelRadius;
@synthesize selectedSliceStroke = _selectedSliceStroke;
@synthesize selectedSliceOffsetRadius = _selectedSliceOffsetRadius;
@synthesize showPercentage = _showPercentage;
@synthesize name = _name;

- (id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self)
    {
        
        _renderer  = [[CARadialGradientRenderer alloc] init];
        
        self.backgroundColor = [UIColor clearColor];
        _pieView = [[UIView alloc] initWithFrame:frame];
        [_pieView setBackgroundColor:[UIColor clearColor]];
        [self addSubview:_pieView];
        

        _startPieAngle = -M_PI_2;
        _selectedSliceStroke = 3.0;
        
        self.pieRadius = MIN(frame.size.width/2, frame.size.height/2) - 10;
        self.pieCenter = CGPointMake(frame.size.width/2, frame.size.height/2);
        self.labelFont = [UIFont boldSystemFontOfSize:MAX((int)self.pieRadius/10, 5)];
        _labelColor = [UIColor whiteColor];
        _labelRadius = _pieRadius/2;
        _selectedSliceOffsetRadius = MAX(10, _pieRadius/10);
        _pieAnlgeStep = (M_PI_2 / 3.0);
        
        CGFloat scale = [[UIScreen mainScreen] scale];
   
        _centerBackgroundLayer = [CALayer layer];
        
        _centerBackgroundLayer.contentsGravity = kCAGravityResizeAspectFill;
       // _centerBackgroundLayer.contents = (id)[UIImage imageNamed:@"pie_center.png"].CGImage;
        
        _centerContentLayer = [CALayer layer];
    
        _centerContentLayer.contentsGravity = kCAGravityCenter;
        _centerBackgroundLayer.contentsScale = _centerContentLayer.contentsScale = scale;
        [_centerBackgroundLayer addSublayer:_centerContentLayer];
        
        //_centerContentLayer.delegate =  _pieView.layer.delegate = _centerBackgroundLayer.delegate = _renderer;
        
        /*
        CABasicAnimation* fadeAnim = [CABasicAnimation animationWithKeyPath:@"contents"];
        fadeAnim.fromValue = [NSNumber numberWithFloat:1.0];
        fadeAnim.toValue = [NSNumber numberWithFloat:0.0];
        fadeAnim.duration = 5.0;
        [_pieView.layer addAnimation:fadeAnim forKey:@"contents"];
        [_centerContentLayer addAnimation:fadeAnim forKey:@"contents"];
        */
        [self.layer addSublayer:_centerBackgroundLayer];
        
        _showLabel = YES;
        _showPercentage = YES;
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame Center:(CGPoint)center Radius:(CGFloat)radius{
    self = [self initWithFrame:frame];
    if (self)
    {
        self.pieCenter = center;
        self.pieRadius = radius;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder{
    self = [super initWithCoder:aDecoder];
    if(self)
    {
        _pieView = [[UIView alloc] initWithFrame:self.bounds];
        [_pieView setBackgroundColor:[UIColor clearColor]];
        [self insertSubview:_pieView atIndex:0];
        _pieView.layer.delegate = self;
        _animationSpeed = 0.5;
        _startPieAngle = 0;
        _selectedSliceStroke = 3.0;
        
        CGRect bounds = [[self layer] bounds];
        self.pieRadius = MIN(bounds.size.width/2, bounds.size.height/2) - 10;
        self.pieRadiusInner = 5.0;
        
        self.pieCenter = CGPointMake(bounds.size.width/2, bounds.size.height/2);
        self.labelFont = [UIFont boldSystemFontOfSize:MAX((int)self.pieRadius/10, 5)];
        _labelColor = [UIColor whiteColor];
        _labelRadius = _pieRadius/2;
        _selectedSliceOffsetRadius = MAX(10, _pieRadius/10);
        
        _showLabel = YES;
        _showPercentage = YES;
    }
    return self;
}

- (void)setPieCenter:(CGPoint)pieCenter{
    [_pieView setCenter:pieCenter];
    _pieCenter = CGPointMake(_pieView.frame.size.width/2, _pieView.frame.size.height/2);
}

- (void)setPieRadius:(CGFloat)pieRadius{
    _pieRadius = pieRadius;
    CGPoint origin = _pieView.frame.origin;
    CGRect frame = CGRectMake(origin.x+_pieCenter.x-pieRadius, origin.y+_pieCenter.y-pieRadius, pieRadius*2, pieRadius*2);
    _pieCenter = CGPointMake(frame.size.width/2, frame.size.height/2);
    [_pieView setFrame:frame];
    [_pieView.layer setCornerRadius:_pieRadius];
}

- (void)setPieBackgroundColor:(UIColor *)color{
    [_pieView setBackgroundColor:color];
}

#pragma mark - manage settings

- (void)setShowPercentage:(BOOL)showPercentage{
    _showPercentage = showPercentage;
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
                
                colors[index] = [_dataSource pieChart:self colorForSliceAtIndex:index];
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
        
            
            UIGraphicsBeginImageContextWithOptions(parentLayer.bounds.size, NO, 0);
            
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
        {
        CGContextSetStrokeColorWithColor(ctx, [UIColor clearColor].CGColor );
        
        CGContextSetBlendMode(ctx, kCGBlendModeClear);
        
        CGMutablePathRef pathMarks = CGPathCreateMutable();
        
        CGFloat radius = _pieRadius;
        CGPoint center = _pieCenter;
        
        // Initialise
        
        float width             = _pieRadiusInner;
        float radius_inner      = (radius - width);
        
        float angle_step = _pieAnlgeStep;
        
        for (float angle = 0; angle <= M_PI * 2.0; angle += angle_step) {
            
            CGPoint pInner = CGPointMake(center.x + radius_inner * cosf(angle), center.y + radius_inner * sinf(angle));
            CGPoint pOuter = CGPointMake(center.x + radius * cosf(angle), center.y + radius * sinf(angle));
            
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

-(void)renderPieInContext:(CGContextRef)ctx fromAngle:(float)angleStart toAngleAngleEnd:(float)angleEnd withColor:(UIColor *)color{
    
    //DLog(@"Render background for piechart: %i slice at index: %i",pieChart.tag, index);
    
    CGFloat radius = _pieRadius;
    CGPoint center = _pieCenter;
    
    // Initialise
    
    float width             = _pieRadiusInner;
    float radius_inner      = (radius - width);
    
    ////DLog(@"Rendering for width: %.1f", width);
    CGPathRef path = CGPathCreateArc(center, radius, _pieRadiusInner, angleStart, angleEnd);
    
    
    CGFloat red         = [color red];
    CGFloat gre         = [color green];
    CGFloat blu         = [color blue];
    
    CGFloat alpaStart    = [color alpha];
    CGFloat alphaEnd     = alpaStart * 0.5;
    
    
    CGContextSaveGState(ctx);
    
    CGContextAddPath(ctx, path);
    CGContextClip(ctx);
    // Render a radial background
    // http://developer.apple.com/library/ios/#documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_shadings/dq_shadings.html
    
    
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
    
    
    CGContextRestoreGState(ctx);
    
}

#pragma mark - Pie Layer Creation Method
-(CALayer *)pieParentLayer{return _pieView.layer;}
-(void)layoutSubviews{

    [super layoutSubviews];
    
    
    // Layout center layers:
    
    CGFloat mx = self.pieRadiusInner;
    CGFloat W = CGRectGetWidth(self.bounds);
    CGFloat w = W - 2.0 * mx;
    
    CGRect f = CGRectIntegral(CGRectMake(mx + 1, mx + 1, w - 2, w - 2));
    
   
    _centerBackgroundLayer.frame = f;
    _centerContentLayer.frame = _centerBackgroundLayer.bounds;
    _centerBackgroundLayer.cornerRadius = _centerContentLayer.cornerRadius = w/2;
    
    [self reloadData];
}

@end

@implementation CARadialGradientRenderer : NSObject

@synthesize pieChart = _pieChart;
@synthesize sliceLayer = _sliceLayer;


 
 - (id<CAAction>)actionForLayer:(CALayer *)theLayer
 forKey:(NSString *)theKey {
 CATransition *theAnimation=nil;
 
 if ([theKey isEqualToString:@"contents"]) {
 
 theAnimation = [[CATransition alloc] init];
 theAnimation.duration = 1.0;
 theAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
 theAnimation.type = kCATransitionFade;
 //theAnimation.subtype = kCATransitionFade;
 }
 return theAnimation;
 }
 
/*
- (id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)key {
    return [NSNull null];
}
 */

@end
