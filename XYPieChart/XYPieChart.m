
#import "XYPieChart.h"
#import <QuartzCore/QuartzCore.h>



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

- (void)createArcAnimationForKey:(NSString *)key fromValue:(NSNumber *)from toValue:(NSNumber *)to Delegate:(id)delegate{
    CABasicAnimation *arcAnimation = [CABasicAnimation animationWithKeyPath:key];
    NSNumber *currentAngle = [[self presentationLayer] valueForKey:key];
    if(!currentAngle) currentAngle = from;
    [arcAnimation setFromValue:currentAngle];
    [arcAnimation setToValue:to];         
    [arcAnimation setDelegate:delegate];
    [arcAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault]];
    [self addAnimation:arcAnimation forKey:key];
    [self setValue:to forKey:key];
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
    NSInteger _selectedSliceIndex;
    //pie view, contains all slices
    UIView  *_pieView;
    
    //animation control
    NSTimer *_animationTimer;
    NSMutableArray *_animations;
    NSMutableArray *_sliceLayers;
    
}

static NSUInteger kDefaultSliceZOrder = 100;

@synthesize dataSource = _dataSource;
@synthesize delegate = _delegate;
@synthesize startPieAngle = _startPieAngle;
@synthesize animationSpeed = _animationSpeed;
@synthesize pieCenter = _pieCenter;
@synthesize pieRadius = _pieRadius;
@synthesize pieRadiusInner = _pieRadiusInner;
@synthesize showLabel = _showLabel;
@synthesize labelFont = _labelFont;
@synthesize labelColor = _labelColor;
@synthesize labelShadowColor = _labelShadowColor;
@synthesize labelRadius = _labelRadius;
@synthesize selectedSliceStroke = _selectedSliceStroke;
@synthesize selectedSliceOffsetRadius = _selectedSliceOffsetRadius;
@synthesize showPercentage = _showPercentage;
@synthesize pieLayers = _sliceLayers;


- (id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.backgroundColor = [UIColor clearColor];
        _pieView = [[UIView alloc] initWithFrame:frame];
        [_pieView setBackgroundColor:[UIColor clearColor]];
        [self addSubview:_pieView];
        
        _selectedSliceIndex = -1;
        _animations = [[NSMutableArray alloc] init];
        _sliceLayers = [[NSMutableArray alloc] init];
        
        _animationSpeed = 0.5;
        _startPieAngle = 0;//M_PI_2*3;
        _selectedSliceStroke = 3.0;
        
        self.pieRadius = MIN(frame.size.width/2, frame.size.height/2) - 10;
        self.pieCenter = CGPointMake(frame.size.width/2, frame.size.height/2);
        self.labelFont = [UIFont boldSystemFontOfSize:MAX((int)self.pieRadius/10, 5)];
        _labelColor = [UIColor whiteColor];
        _labelRadius = _pieRadius/2;
        _selectedSliceOffsetRadius = MAX(10, _pieRadius/10);
        
        CGFloat scale = [[UIScreen mainScreen] scale];
   
        _centerBackgroundLayer = [CALayer layer];
        _centerBackgroundLayer.contentsGravity = kCAGravityResizeAspectFill;
        _centerBackgroundLayer.contents = (id)[UIImage imageNamed:@"pie_center.png"].CGImage;
        
        _centerContentLayer = [CALayer layer];
        _centerContentLayer.contentsGravity = kCAGravityCenter;
        _centerBackgroundLayer.contentsScale = _centerContentLayer.contentsScale = scale;
        [_centerBackgroundLayer addSublayer:_centerContentLayer];
        
        [self.layer addSublayer:_centerBackgroundLayer];
        
    
        /*
        _centerBackgroundLayer.borderWidth = 1.0;
        _centerBackgroundLayer.borderColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:0.5].CGColor;
        
        _centerContentLayer.borderWidth = 2.0;
        _centerContentLayer.borderColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.5].CGColor;
        */
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
        
        _selectedSliceIndex = -1;
        _animations = [[NSMutableArray alloc] init];
        _sliceLayers = [[NSMutableArray alloc] init];
        
        _animationSpeed = 0.5;
        _startPieAngle = 0;//M_PI_2*3;
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
    for(SliceLayer *layer in _sliceLayers)
    {
        CATextLayer *textLayer = [[layer sublayers] objectAtIndex:0];
        [textLayer setHidden:!_showLabel];
        if(!_showLabel) return;
        NSString *label;
        if(_showPercentage)
            label = [NSString stringWithFormat:@"%0.0f", layer.percentage*100];
        else
            label = (layer.text)?layer.text:[NSString stringWithFormat:@"%0.0f", layer.value];
        CGSize size = [label sizeWithFont:self.labelFont];
        
        if(M_PI*2*_labelRadius*layer.percentage < MAX(size.width,size.height))
        {
            [textLayer setString:@""];
        }
        else
        {
            [textLayer setString:label];
            [textLayer setBounds:CGRectMake(0, 0, size.width, size.height)];
        }
    }
}

#pragma mark - Pie Reload Data With Animation

- (void)reloadData{
    
    CALayer *parentLayer = [self pieParentLayer];
    
    _selectedSliceIndex = -1;
    [_sliceLayers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        SliceLayer *layer = (SliceLayer *)obj;
        
        layer.backgroundRenderer.pieChart = nil;
        layer.backgroundRenderer = nil;
        
        //if(layer.isSelected)
        [layer.mask removeFromSuperlayer];
        layer.mask = nil;
        
        //  [self setSliceDeselectedAtIndex:idx];
        [layer.backgroundLayer removeFromSuperlayer];
        [layer removeFromSuperlayer];
    }];
    
    for (CALayer *layer in parentLayer.sublayers) {
        layer.delegate = nil;
        [layer removeFromSuperlayer];
    }
    
    [_sliceLayers removeAllObjects];
    
    
    
    if (_dataSource){
        
        double startToAngle = 0.0;
        double endToAngle = startToAngle;
        
        NSUInteger sliceCount = [_dataSource numberOfSlicesInPieChart:self];
        
        double sum = 0.0;
        double values[sliceCount];
        for (int index = 0; index < sliceCount; index++) {
            values[index] = [_dataSource pieChart:self valueForSliceAtIndex:index];
            sum += values[index];
        }
        
        double angles[sliceCount];
        
        for (int index = 0; index < sliceCount; index++) {
            double div;
            if (sum == 0)
                div = 0;
            else
                div = values[index] / sum; 
            angles[index] = M_PI * 2 * div;
        }

        [CATransaction begin];
        [CATransaction setAnimationDuration:_animationSpeed];
        
        [_pieView setUserInteractionEnabled:NO];
        
        __block NSMutableArray *layersToRemove = nil;
        
        BOOL isOnStart = ([_sliceLayers count] == 0 && sliceCount);
        NSInteger diff = sliceCount - [_sliceLayers count];
        layersToRemove = [NSMutableArray arrayWithArray:_sliceLayers];
        
        BOOL isOnEnd = ([_sliceLayers count] && (sliceCount == 0 || sum <= 0));
        
        if(isOnEnd)
        {
            for(SliceLayer *layer in _sliceLayers){

                [layer createArcAnimationForKey:@"startAngle"
                                      fromValue:[NSNumber numberWithDouble:_startPieAngle]
                                        toValue:[NSNumber numberWithDouble:_startPieAngle] 
                                       Delegate:self];
                [layer createArcAnimationForKey:@"endAngle" 
                                      fromValue:[NSNumber numberWithDouble:_startPieAngle]
                                        toValue:[NSNumber numberWithDouble:_startPieAngle] 
                                       Delegate:self];
            }
            [CATransaction commit];
            return;
        }
        
        for(int index = 0; index < sliceCount; index ++)
        {
            SliceLayer *layer;
            double angle = angles[index];
            endToAngle += angle;
            double startFromAngle = _startPieAngle + startToAngle;
            double endFromAngle = _startPieAngle + endToAngle;
            
            if( index >= [_sliceLayers count] )
            {
                layer = [self createSliceLayerAtIndex:index];
                if (isOnStart)
                    startFromAngle = endFromAngle = _startPieAngle;
                [parentLayer addSublayer:layer.backgroundLayer];
                [_sliceLayers addObject:layer];
                
                diff--;
            }
            else
            {
                SliceLayer *onelayer = [_sliceLayers objectAtIndex:index];
                if(diff == 0 || onelayer.value == (CGFloat)values[index])
                {
                    layer = onelayer;
                    [layersToRemove removeObject:layer];
                }
                else if(diff > 0)
                {
                    layer = [self createSliceLayerAtIndex:index];
                    [parentLayer insertSublayer:layer.backgroundLayer atIndex:index];
                    [_sliceLayers insertObject:layer atIndex:index];
                    diff--;
                }
                else if(diff < 0)
                {
                    while(diff < 0) 
                    {
                        [onelayer.backgroundLayer removeFromSuperlayer];
                        [_sliceLayers removeObject:onelayer];
                        [parentLayer addSublayer:onelayer.backgroundLayer];
                        [_sliceLayers addObject:onelayer];
                        
                        diff++;
                        onelayer = [_sliceLayers objectAtIndex:index];
                        
                        if(onelayer.value == (CGFloat)values[index] || diff == 0)
                        {
                            layer = onelayer;
                            [layersToRemove removeObject:layer];
                            break;
                        }
                    }
                }
            }
            
            layer.value = values[index];
            layer.percentage = (sum)?layer.value/sum:0;
            
            UIColor *color = [UIColor blueColor];
            
            if (_dataSource && [_dataSource respondsToSelector:@selector(pieChart:colorForSliceAtIndex:)]) {
                color = [_dataSource pieChart:self colorForSliceAtIndex:index];
            }
            [layer setFillColor:color.CGColor];
            
            
            [layer createArcAnimationForKey:@"startAngle"
                                  fromValue:[NSNumber numberWithDouble:startFromAngle]
                                    toValue:[NSNumber numberWithDouble:startToAngle+_startPieAngle] 
                                   Delegate:self];
            [layer createArcAnimationForKey:@"endAngle" 
                                  fromValue:[NSNumber numberWithDouble:endFromAngle]
                                    toValue:[NSNumber numberWithDouble:endToAngle+_startPieAngle] 
                                   Delegate:self];
            
            startToAngle = endToAngle;
        }
        [CATransaction setDisableActions:YES];
        
        for(SliceLayer *layer in layersToRemove)
        {
            layer.backgroundRenderer.pieChart = nil;
            layer.backgroundRenderer = nil;
            [layer.backgroundLayer removeFromSuperlayer];
            
            [layer setFillColor:[self backgroundColor].CGColor];
            [layer setDelegate:nil];
            [layer.backgroundLayer setZPosition:0];
            CATextLayer *textLayer = [[layer sublayers] objectAtIndex:0];
            [textLayer setHidden:YES];
        }
        
        [layersToRemove enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            SliceLayer *lay = (SliceLayer *)obj;
            
            lay.backgroundRenderer.pieChart = nil;
            lay.backgroundRenderer = nil;
            [lay.backgroundLayer removeFromSuperlayer];
            [_sliceLayers removeObject:lay];
//            [lay removeFromSuperlayer];
        }];
        
        [layersToRemove removeAllObjects];
        
        for(SliceLayer *layer in _sliceLayers)
        {
            [layer.backgroundLayer setZPosition:kDefaultSliceZOrder];
        }
        
        [_pieView setUserInteractionEnabled:YES];
        
        [CATransaction setDisableActions:NO];
        [CATransaction commit];
    }
    
    [self setNeedsDisplay];
}

#pragma mark - Animation Delegate + Run Loop Timer

- (void)updateTimerFired:(NSTimer *)timer;{

    [_sliceLayers enumerateObjectsUsingBlock:^(CAShapeLayer * obj, NSUInteger idx, BOOL *stop) {
        
        NSNumber *presentationLayerStartAngle = [[obj presentationLayer] valueForKey:@"startAngle"];
        CGFloat interpolatedStartAngle = [presentationLayerStartAngle doubleValue];
        
        NSNumber *presentationLayerEndAngle = [[obj presentationLayer] valueForKey:@"endAngle"];
        CGFloat interpolatedEndAngle = [presentationLayerEndAngle doubleValue];

        CGPathRef path = CGPathCreateArc(_pieCenter, _pieRadius, _pieRadiusInner, interpolatedStartAngle, interpolatedEndAngle);
        [obj setPath:path];
        CFRelease(path);
        
        {
            CALayer *labelLayer = [[obj sublayers] objectAtIndex:0];
            CGFloat interpolatedMidAngle = (interpolatedEndAngle + interpolatedStartAngle) / 2;        
            [CATransaction setDisableActions:YES];
            [labelLayer setPosition:CGPointMake(_pieCenter.x + (_labelRadius * cos(interpolatedMidAngle)), _pieCenter.y + (_labelRadius * sin(interpolatedMidAngle)))];
            [CATransaction setDisableActions:NO];
        }
    }];
}

- (void)animationDidStart:(CAAnimation *)anim{
    if (_animationTimer == nil) {
        static float timeInterval = 1.0/60.0;
        // Run the animation timer on the main thread.
        // We want to allow the user to interact with the UI while this timer is running.
        // If we run it on this thread, the timer will be halted while the user is touching the screen (that's why the chart was disappearing in our collection view).
        _animationTimer= [NSTimer timerWithTimeInterval:timeInterval target:self selector:@selector(updateTimerFired:) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:_animationTimer forMode:NSRunLoopCommonModes];
    }
    
    [_animations addObject:anim];
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)animationCompleted{
    [_animations removeObject:anim];
    
    if ([_animations count] == 0) {
        [_animationTimer invalidate];
        _animationTimer = nil;
    }
}

#pragma mark - Touch Handing (Selection Notification)

- (NSInteger)getCurrentSelectedOnTouch:(CGPoint)point{
    __block NSUInteger selectedIndex = -1;
    
    CGAffineTransform transform = CGAffineTransformIdentity;

    [_sliceLayers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        SliceLayer *pieLayer = (SliceLayer *)obj;
        CGPathRef path = [pieLayer path];
        
        if (CGPathContainsPoint(path, &transform, point, 0)) {
            [pieLayer setLineWidth:_selectedSliceStroke];
            [pieLayer setStrokeColor:[UIColor whiteColor].CGColor];
            [pieLayer setLineJoin:kCALineJoinBevel];
            [pieLayer setZPosition:MAXFLOAT];
            selectedIndex = idx;
        } else {
            [pieLayer setZPosition:kDefaultSliceZOrder];
            [pieLayer setLineWidth:0.0];
        }
    }];
    return selectedIndex;
}


#pragma mark - Selection Notification

- (void)notifyDelegateOfSelectionChangeFrom:(NSUInteger)previousSelection to:(NSUInteger)newSelection
{
    if (previousSelection != newSelection){
        if(previousSelection != -1){
            NSUInteger tempPre = previousSelection;
            if ([_delegate respondsToSelector:@selector(pieChart:willDeselectSliceAtIndex:)])
                [_delegate pieChart:self willDeselectSliceAtIndex:tempPre];
            [self setSliceDeselectedAtIndex:tempPre];
            previousSelection = newSelection;
            if([_delegate respondsToSelector:@selector(pieChart:didDeselectSliceAtIndex:)])
                [_delegate pieChart:self didDeselectSliceAtIndex:tempPre];
        }
        
        if (newSelection != -1){
            if([_delegate respondsToSelector:@selector(pieChart:willSelectSliceAtIndex:)])
                [_delegate pieChart:self willSelectSliceAtIndex:newSelection];
            [self setSliceSelectedAtIndex:newSelection];
            _selectedSliceIndex = newSelection;
            if([_delegate respondsToSelector:@selector(pieChart:didSelectSliceAtIndex:)])
                [_delegate pieChart:self didSelectSliceAtIndex:newSelection];
        }
    }else if (newSelection != -1){
        SliceLayer *layer = [_sliceLayers objectAtIndex:newSelection];
        if(_selectedSliceOffsetRadius > 0 && layer){
            if (layer.isSelected) {
                if ([_delegate respondsToSelector:@selector(pieChart:willDeselectSliceAtIndex:)])
                    [_delegate pieChart:self willDeselectSliceAtIndex:newSelection];
                [self setSliceDeselectedAtIndex:newSelection];
                if (newSelection != -1 && [_delegate respondsToSelector:@selector(pieChart:didDeselectSliceAtIndex:)])
                    [_delegate pieChart:self didDeselectSliceAtIndex:newSelection];
                previousSelection = _selectedSliceIndex = -1;
            }else{
                if ([_delegate respondsToSelector:@selector(pieChart:willSelectSliceAtIndex:)])
                    [_delegate pieChart:self willSelectSliceAtIndex:newSelection];
                [self setSliceSelectedAtIndex:newSelection];
                previousSelection = _selectedSliceIndex = newSelection;
                if (newSelection != -1 && [_delegate respondsToSelector:@selector(pieChart:didSelectSliceAtIndex:)])
                    [_delegate pieChart:self didSelectSliceAtIndex:newSelection];
            }
        }
    }
}
#pragma mark - Selection Programmatically Without Notification

- (void)setSliceSelectedAtIndex:(NSInteger)index
{
    if(_selectedSliceOffsetRadius <= 0)
        return;
    SliceLayer *layer = [_sliceLayers objectAtIndex:index];
    if (layer && !layer.isSelected) {
        CGPoint currPos = layer.position;
        double middleAngle = (layer.startAngle + layer.endAngle)/2.0;
        CGPoint newPos = CGPointMake(currPos.x + _selectedSliceOffsetRadius*cos(middleAngle), currPos.y + _selectedSliceOffsetRadius*sin(middleAngle));
        layer.position = newPos;
        layer.isSelected = YES;
    }
}

- (void)setSliceDeselectedAtIndex:(NSInteger)index
{
    if(_selectedSliceOffsetRadius <= 0)
        return;
    SliceLayer *layer = [_sliceLayers objectAtIndex:index];
    if (layer && layer.isSelected) {
        layer.position = CGPointMake(0, 0);
        layer.isSelected = NO;
    }
}

#pragma mark - Pie Layer Creation Method
-(CALayer *)pieParentLayer{return _pieView.layer;}

- (SliceLayer *)createSliceLayerAtIndex:(NSUInteger)index
{
    SliceLayer *pieLayer = [SliceLayer layer];
    [pieLayer setStrokeColor:NULL];
    
    CALayer *maskedLayer = [CALayer layer];
    maskedLayer.frame = [self pieParentLayer].bounds;
    [maskedLayer setZPosition:0];
    [maskedLayer setNeedsDisplayOnBoundsChange:YES];
    //pieLayer.masksToBounds = maskedLayer.masksToBounds = YES;
    //[maskedLayer addSublayer:pieLayer];
    [maskedLayer setMask:pieLayer];
    
    pieLayer.backgroundLayer = maskedLayer;
    
    CARadialGradientRenderer *renderer = [[CARadialGradientRenderer alloc] init];
    renderer.pieChart = self;
    pieLayer.backgroundRenderer = renderer;
    //maskedLayer.borderWidth = 1.0;
    //maskedLayer.borderColor = [UIColor whiteColor].CGColor;
    maskedLayer.backgroundColor = [UIColor clearColor].CGColor;
    maskedLayer.delegate = renderer;
    maskedLayer.contentsScale = pieLayer.contentsScale = [[UIScreen mainScreen] scale];
    
    [maskedLayer setNeedsDisplayOnBoundsChange:YES];
    [pieLayer setNeedsDisplayOnBoundsChange:YES];
    
    [pieLayer setNeedsDisplay];
    [maskedLayer setNeedsDisplay];
    
    //maskedLayer.borderWidth = 1.0;
    //pieLayer.borderWidth = 1.0;
    return pieLayer;
}

-(void)layoutSubviews{

    [super layoutSubviews];
    
    for (CALayer * layer in [self pieParentLayer].sublayers) {
        layer.frame = [self pieParentLayer].bounds;
    }
    
    // Layout center layers:
    
    CGFloat mx = self.pieRadiusInner;
    CGFloat W = CGRectGetWidth(self.bounds);
    CGFloat w = W - 2.0 * mx;
    
    CGRect f = CGRectMake(mx + 1, mx + 1, w - 2, w - 2);
    
   
    _centerBackgroundLayer.frame = f;
    _centerContentLayer.frame = _centerBackgroundLayer.bounds;
    _centerBackgroundLayer.cornerRadius = _centerContentLayer.cornerRadius = w/2;
    
}

@end

@implementation CARadialGradientRenderer : NSObject

@synthesize pieChart = _pieChart;
@synthesize sliceLayer = _sliceLayer;
  

-(void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx{

    NSUInteger index = [_pieChart.pieLayers indexOfObject:self.sliceLayer];
    
    [_pieChart.dataSource pieChart:_pieChart renderPieBackgroundInContext:ctx forBackgroundLayer:layer sliceLayer:self.sliceLayer atIndex:index];
    
}

@end
