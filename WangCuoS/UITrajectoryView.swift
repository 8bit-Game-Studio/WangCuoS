//
//  UITrajectoryView.swift
//  WangCuoS
//
//  Created by EyreFree on 15/4/17.
//  Copyright (c) 2015年 eyrefree. All rights reserved.
//

import UIKit
import Accelerate
import QuartzCore

class UITrajectoryView: UIView {
    var controller:TouchController!
    
    var blurValue:CGFloat = 0.1
    var lineWidth:CGFloat = 20.0
    
    var pathImage:UIImage!      //黑白图
    var oriImage:UIImage!       //背景图
    var backImage:UIImage!      //前景图
    
    var lineColor:UIColor = UIColor.blackColor()
    var pointOld:CGPoint!       //最旧的点
    var pointLast:CGPoint!      //上一个点
    var pointNow:CGPoint!       //最新的点
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.whiteColor()
        pathImage = createImageWithColor(
            UIColor(red: 255/255.0, green: 255/255.0, blue: 255/255.0, alpha: 1)
        )
        setBackgroundImage(
            createGradientImageWithColor(
                UIColor(red: 211/255.0, green: 211/255.0, blue: 211/255.0, alpha: 1)
            )
        )
        return
    }
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        backgroundColor = UIColor.whiteColor()
        pathImage = createImageWithColor(
            UIColor(red: 255/255.0, green: 255/255.0, blue: 255/255.0, alpha: 1)
        )
        setBackgroundImage(
            createGradientImageWithColor(
                UIColor(red: 211/255.0, green: 211/255.0, blue: 211/255.0, alpha: 1)
            )
        )
        return
    }
    
    func setSuperController(superController:TouchController) {
        controller = superController
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        pointOld = (touches as NSSet).anyObject()?.locationInView(self)
        pointLast = (touches as NSSet).anyObject()?.locationInView(self)
        pointNow = (touches as NSSet).anyObject()?.locationInView(self)
        
        //触发Moved
        touchesMoved(touches, withEvent:event);
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        pointOld = pointLast
        pointLast = pointNow
        pointNow = (touches as NSSet).anyObject()?.locationInView(self)
        
        //计算中间点
        let mid1:CGPoint = midPoint(pointOld, p2: pointLast)
        let mid2:CGPoint = midPoint(pointNow, p2: pointLast)
        
        //创建这一次touchu的新的path
        let path = CGPathCreateMutable()
        
        CGPathMoveToPoint(path, nil, mid1.x, mid1.y)
        CGPathAddQuadCurveToPoint(path, nil, pointLast.x, pointLast.y, mid2.x, mid2.y)
        /*
        CGPathMoveToPoint(path, nil, mid2.x, mid2.y)
        CGPathAddQuadCurveToPoint(path, nil, mid1.x, mid1.y, pointLast.x, pointLast.y)
        */
        //获取包围path的矩形区域，减少重绘工作量
        var drawBox = CGPathGetBoundingBox(path)
        //计算线宽因素扩大矩形区域使得能够完全容纳path区域
        drawBox.origin.x -= lineWidth * 2
        drawBox.origin.y -= lineWidth * 2
        drawBox.size.width += lineWidth * 4
        drawBox.size.height += lineWidth * 4
        
        //好像是创建一个上下文
        UIGraphicsBeginImageContext(bounds.size)
        let currentContext:CGContextRef = UIGraphicsGetCurrentContext()
        //绘制path到当前context
        if (nil != path) {
            CGContextSetLineWidth(currentContext, lineWidth)
            //直线圆角
            CGContextSetLineCap(currentContext, kCGLineCapRound)
            CGContextSetStrokeColorWithColor(currentContext, lineColor.CGColor)
            CGContextAddPath(currentContext, path)
            CGContextDrawPath(currentContext, kCGPathStroke)
        }
        //获取刚画的这一笔
        let yibiPathImage = UIGraphicsGetImageFromCurrentImageContext()
        
        //将刚画的这一笔合成到pathimage上去
        pathImage.drawInRect(bounds)
        yibiPathImage.drawInRect(bounds)
        pathImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        //重绘包围path的矩形区域
        setNeedsDisplayInRect(drawBox)
    }
    
    //把这个消息传上去
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if (nil != controller) {
            controller.touchesEnded(touches, withEvent: event)
        }
    }
    
    override func drawRect(rect: CGRect) {
        //绘制渐变背景色
        backImage.drawInRect(CGRectMake(0, 0, bounds.width, bounds.height))
        //path高斯模糊,并绘制与前景的叠加图
        if (nil != pathImage) {
            maskImage(oriImage, maskImage: blur(pathImage)).drawInRect(CGRectMake(0, 0, bounds.width, bounds.height))
        }
        super.drawRect(rect)
    }
    
    private func blur(theImage:UIImage)->UIImage {
        //降低图像质量，提高处理速度
        let quality:CGFloat = 0.1
        let imageData:NSData = UIImageJPEGRepresentation(theImage, quality)!
        let blurredImage:UIImage = UIImage(data:imageData)!
        return gaussianBlur(blurredImage, blurParm: blurValue)
    }
    
    //绘制纯色图片
    func createImageWithColor(color: UIColor)->UIImage {
        UIGraphicsBeginImageContext(bounds.size)
        let context = UIGraphicsGetCurrentContext()
        CGContextSetFillColorWithColor(context, color.CGColor)
        CGContextFillRect(context, bounds)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    //绘制渐变图片
    func createGradientImageWithColor(color: UIColor)->UIImage {
        //获取rgb
        var components = CGColorGetComponents(color.CGColor);
        
        //创建渐变规则
        let rgb:CGColorSpaceRef = CGColorSpaceCreateDeviceRGB()
        let colors = [
            components[0], components[1], components[2], 1.00,
            CGFloat(1.0) , 1.0, 1.0, 1.00,
        ]
        
        var newSize = self.bounds.size
        if (nil != oriImage) {
            newSize = oriImage.size
        }
        
        //画图
        UIGraphicsBeginImageContext(newSize)
        CGContextDrawLinearGradient(
            UIGraphicsGetCurrentContext(),
            CGGradientCreateWithColorComponents(rgb, colors, nil, 2),
            CGPointMake(0, 0),
            CGPointMake(0, newSize.height),
            1)
        let rtImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return rtImage
    }
    
    //获取两个点的中点
    private func midPoint(p1:CGPoint, p2:CGPoint)->CGPoint {
        return CGPointMake((p1.x + p2.x) * 0.5, (p1.y + p2.y) * 0.5);
    }
    
    //自定义高斯模糊
    private func gaussianBlur(souImg:UIImage, blurParm:CGFloat)->UIImage {
        //添加alpha通道
        let sourceImg = CopyImageAndAddAlphaChannel(souImg.CGImage!)
        
        var blurAmount:CGFloat = blurParm
        //高斯模糊参数(0-1)之间，超出范围强行转成0.5
        if (blurAmount < 0.0 || blurAmount > 1.0) {
            blurAmount = 0.5
        }
        
        var boxSize = Int(blurAmount * 40)
        boxSize = boxSize - (boxSize % 2) + 1
        
        let img:CGImage = sourceImg
        
        //手动申请内存＋1
        let inBuffer = UnsafeMutablePointer<vImage_Buffer>.alloc(1)
        //手动申请内存＋2
        let outBuffer = UnsafeMutablePointer<vImage_Buffer>.alloc(1)
        var error:vImage_Error!
        
        let inProvider =  CGImageGetDataProvider(img)
        let inBitmapData =  CGDataProviderCopyData(inProvider)
        
        inBuffer.memory.width = vImagePixelCount(CGImageGetWidth(img))
        inBuffer.memory.height = vImagePixelCount(CGImageGetHeight(img))
        inBuffer.memory.rowBytes = CGImageGetBytesPerRow(img)
        inBuffer.memory.data = UnsafeMutablePointer<Void>(CFDataGetBytePtr(inBitmapData))
        
        //手动申请内存＋3
        let pixelBuffer = malloc(CGImageGetBytesPerRow(img) * CGImageGetHeight(img))
        
        outBuffer.memory.width = vImagePixelCount(CGImageGetWidth(img))
        outBuffer.memory.height = vImagePixelCount(CGImageGetHeight(img))
        outBuffer.memory.rowBytes = CGImageGetBytesPerRow(img)
        outBuffer.memory.data = pixelBuffer
        
        error = vImageBoxConvolve_ARGB8888(inBuffer,
            outBuffer, nil, vImagePixelCount(0), vImagePixelCount(0),
            UInt32(boxSize), UInt32(boxSize), nil, vImage_Flags(kvImageEdgeExtend))
        if (nil != error) {
            error = vImageBoxConvolve_ARGB8888(inBuffer,
                outBuffer, nil, vImagePixelCount(0), vImagePixelCount(0),
                UInt32(boxSize), UInt32(boxSize), nil, vImage_Flags(kvImageEdgeExtend))
            if (nil != error) {
                error = vImageBoxConvolve_ARGB8888(inBuffer,
                    outBuffer, nil, vImagePixelCount(0), vImagePixelCount(0),
                    UInt32(boxSize), UInt32(boxSize), nil, vImage_Flags(kvImageEdgeExtend))
            }
        }
        
        let colorSpace =  CGColorSpaceCreateDeviceRGB()
        let ctx = CGBitmapContextCreate(outBuffer.memory.data,
            Int(outBuffer.memory.width),
            Int(outBuffer.memory.height),
            8,
            outBuffer.memory.rowBytes,
            colorSpace,
            //CGBitmapInfo(CGImageAlphaInfo.Last.rawValue))
            CGImageAlphaInfo.PremultipliedLast.rawValue)
        
        let imageRef = CGBitmapContextCreateImage(ctx)
        
        //手动申请的内存释放
        inBuffer.destroy()
        inBuffer.dealloc(1)
        //手动申请内存＋2
        outBuffer.destroy()
        outBuffer.dealloc(1)
        //手动申请内存＋1
        free(pixelBuffer)
        //手动申请内存＋0
        
        return UIImage(CGImage:imageRef)
    }
    
    //混合两张图片
    private func mixImages(backImage:UIImage, frontImage:UIImage)->UIImage {
        UIGraphicsBeginImageContext(frontImage.size)
        backImage.drawAtPoint(CGPointMake(0,0))
        frontImage.drawAtPoint(CGPointMake(0,0))
        let newImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    //初始化，注意这个bgColor必须是rgb颜色空间的...
    func initTrajectoryView(lineWidth:CGFloat, blur:CGFloat, isCover:Bool, image:UIImage) {
        setOriginImage(image)
        setTouchWidth(lineWidth)
        setBlurDegree(blur)
        setTouchState(isCover)
    }
    
    //给图片添加alpha通道，这个函数不知掉有木有问题...
    private func CopyImageAndAddAlphaChannel(sourceImage:CGImageRef)->CGImageRef {
        var retVal:CGImageRef!
        let width =  CGImageGetWidth(sourceImage)
        let height =  CGImageGetHeight(sourceImage)
        let colorSpace =  CGColorSpaceCreateDeviceRGB()
        
        let offscreenContext = CGBitmapContextCreate(nil, width, height,
            8, 0, colorSpace,
            CGImageAlphaInfo.PremultipliedFirst.rawValue | CGBitmapInfo.ByteOrder32Little.rawValue)
        
        if (offscreenContext != nil) {
            CGContextDrawImage(offscreenContext, CGRectMake(0, 0, CGFloat(width), CGFloat(height)), sourceImage)
            retVal = CGBitmapContextCreateImage(offscreenContext)
        }
        
        return retVal
    }
    
    //给图拼添加遮罩
    private func maskImage(oriImage:UIImage, maskImage:UIImage)->UIImage {
        let maskRef = maskImage.CGImage
        let mask = CGImageMaskCreate(CGImageGetWidth(maskRef),
            CGImageGetHeight(maskRef),
            CGImageGetBitsPerComponent(maskRef),
            CGImageGetBitsPerPixel(maskRef),
            CGImageGetBytesPerRow(maskRef),
            CGImageGetDataProvider(maskRef), nil, true)
        
        let sourceImage:CGImageRef = oriImage.CGImage!
        var imageWithAlpha = sourceImage
        
        if (CGImageGetAlphaInfo(sourceImage) == CGImageAlphaInfo.None) {
            imageWithAlpha = CopyImageAndAddAlphaChannel(sourceImage)
        }
        let masked = CGImageCreateWithMask(imageWithAlpha, mask)
        let retImage = UIImage(CGImage:masked)
        return retImage
    }
    
    //设置前景图片
    func setOriginImage(image:UIImage) {
        self.oriImage = image
    }
    
    //设置背景图片
    func setBackgroundImage(bgImg:UIImage) {
        self.backImage = bgImg
    }
    
    //设置模糊度
    func setBlurDegree(blur:CGFloat) {
        self.blurValue = blur
    }
    
    //设置线宽
    func setTouchWidth(percentage:CGFloat) {
        self.lineWidth = percentage * 25 + 3
    }
    
    //设置触摸状态
    func setTouchState(isCover:Bool) {
        self.lineColor = isCover ? UIColor.whiteColor() : UIColor.blackColor()
    }
    
    //还原所有涂抹
    func clearView() {
        pathImage = createImageWithColor(UIColor(red: 255/255.0, green: 255/255.0, blue: 255/255.0, alpha: 1))
        refresh()
    }
    
    //刷新一下玩玩
    func refresh() {
        setNeedsDisplayInRect(self.bounds)
    }
}