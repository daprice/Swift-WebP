//
//  WebPEncoder.swift
//  WebP
//
//  Created by Namai Satoshi on 2016/10/16.
//  Copyright © 2016年 satoshi.namai. All rights reserved.
//

import Foundation
import CWebP

#if os(macOS)
    import AppKit
#endif
#if os(iOS)
    import UIKit
#endif

enum WebPEncodeError : Int, Error {
    case ok = 0
    case outOfMemory           // memory error allocating objects
    case bitstreamOutOfMemory  // memory error while flushing bits
    case nullParameter         // a pointer parameter is NULL
    case invalidConfiguration  // configuration is invalid
    case badDimension          // picture has invalid width/height
    case partition0Overflow    // partition is bigger than 512k
    case partitionOverflow     // partition is bigger than 16M
    case badWrite              // error while flushing bytes
    case fileTooBig            // file is bigger than 4G
    case userAbort             // abort request by user
    case last                  // list terminator. always last.
}

public class WebPEncoder {
    typealias WebPPictureImporter = (UnsafeMutablePointer<WebPPicture>, UnsafeMutablePointer<UInt8>, Int32) -> Int32
    
    public init() {
    }
    
    public func encode(RGB: UnsafeMutablePointer<UInt8>, config: WebPConfig,
                       originWidth: Int, originHeight: Int, stride: Int,
                       resizeWidth: Int = 0, resizeHeight: Int = 0) throws -> Data {
        let importer: WebPPictureImporter = { picturePtr, data, stride in
            return WebPPictureImportRGB(picturePtr, data, stride)
        }
        return try encode(RGB, importer: importer, config: config, originWidth: originWidth, originHeight: originHeight, stride: stride)
    }
    
    public func encode(RGBA: UnsafeMutablePointer<UInt8>, config: WebPConfig,
                       originWidth: Int, originHeight: Int, stride: Int,
                       resizeWidth: Int = 0, resizeHeight: Int = 0) throws -> Data {
        let importer: WebPPictureImporter = { picturePtr, data, stride in
            return WebPPictureImportRGBA(picturePtr, data, stride)
        }
        return try encode(RGBA, importer: importer, config: config, originWidth: originWidth, originHeight: originHeight, stride: stride)
    }
    
    public func encode(RGBX: UnsafeMutablePointer<UInt8>, config: WebPConfig,
                       originWidth: Int, originHeight: Int, stride: Int,
                       resizeWidth: Int = 0, resizeHeight: Int = 0) throws -> Data {
        let importer: WebPPictureImporter = { picturePtr, data, stride in
            return WebPPictureImportRGBX(picturePtr, data, stride)
        }
        return try encode(RGBX, importer: importer, config: config, originWidth: originWidth, originHeight: originHeight, stride: stride)
    }
    
    public func encode(BGR: UnsafeMutablePointer<UInt8>, config: WebPConfig,
                       originWidth: Int, originHeight: Int, stride: Int,
                       resizeWidth: Int = 0, resizeHeight: Int = 0) throws -> Data {
        let importer: WebPPictureImporter = { picturePtr, data, stride in
            return WebPPictureImportBGR(picturePtr, data, stride)
        }
        return try encode(BGR, importer: importer, config: config, originWidth: originWidth, originHeight: originHeight, stride: stride)
    }
    
    public func encode(BGRA: UnsafeMutablePointer<UInt8>, config: WebPConfig,
                       originWidth: Int, originHeight: Int, stride: Int,
                       resizeWidth: Int = 0, resizeHeight: Int = 0) throws -> Data {
        let importer: WebPPictureImporter = { picturePtr, data, stride in
            return WebPPictureImportBGRA(picturePtr, data, stride)
        }
        return try encode(BGRA, importer: importer, config: config, originWidth: originWidth, originHeight: originHeight, stride: stride)
    }
    
    public func encode(BGRX: UnsafeMutablePointer<UInt8>, config: WebPConfig,
                       originWidth: Int, originHeight: Int, stride: Int,
                       resizeWidth: Int = 0, resizeHeight: Int = 0) throws -> Data {
        let importer: WebPPictureImporter = { picturePtr, data, stride in
            return WebPPictureImportBGRX(picturePtr, data, stride)
        }
        return try encode(BGRX, importer: importer, config: config, originWidth: originWidth, originHeight: originHeight, stride: stride)
    }
    
    private func encode(_ dataPtr: UnsafeMutablePointer<UInt8>, importer: WebPPictureImporter,
                        config: WebPConfig, originWidth: Int, originHeight: Int, stride: Int,
                        resizeWidth: Int = 0, resizeHeight: Int = 0) throws -> Data {
        var config = config.rawValue
        if WebPValidateConfig(&config) == 0 {
            throw WebPError.invalidParameter
        }
        
        var picture = WebPPicture()
        if WebPPictureInit(&picture) == 0 {
            fatalError("version error")
        }
        
        picture.use_argb = 1
        picture.width = Int32(originWidth)
        picture.height = Int32(originHeight)
        
        if WebPPictureAlloc(&picture) == 0 {
            fatalError("memory error")
        }
        
        let ok = importer(&picture, dataPtr, Int32(stride))
        if ok == 0 {
            WebPPictureFree(&picture)
            throw WebPError.importError
        }
        
        if resizeHeight > 0 && resizeHeight > 0 {
            if (WebPPictureRescale(&picture, Int32(resizeWidth), Int32(resizeHeight)) == 0) {
                throw WebPError.encodeError
            }
        }
        
        var buffer = WebPMemoryWriter()
        WebPMemoryWriterInit(&buffer)
        let writeWebP: @convention(c) (UnsafePointer<UInt8>?, Int, UnsafePointer<WebPPicture>?) -> Int32 = { (data, size, picture) -> Int32 in
            return WebPMemoryWrite(data, size, picture)
        }
        picture.writer = writeWebP
        picture.custom_ptr = UnsafeMutableRawPointer(&buffer)
        
        if WebPEncode(&config, &picture) == 0 {
            let error = WebPEncodeError(rawValue:  Int(picture.error_code.rawValue))!
            print("encode error \(error)")
            throw error
        }
        
        return Data(bytes: buffer.mem, count: buffer.size)
    }
}

extension WebPEncoder {
    #if os(macOS)
    
    public func encode(_ image: NSImage, config: WebPConfig, width: Int = 0, height: Int = 0) throws -> Data {
    let data = image.tiffRepresentation!
    let stride = Int(image.size.width) * MemoryLayout<UInt8>.size * 3 // RGB = 3byte
    let bitmap = NSBitmapImageRep(data: data)!
    let webPData = try encode(RGB: bitmap.bitmapData!, config: config,
    originWidth: Int(image.size.width), originHeight: Int(image.size.height), stride: stride,
    resizeWidth: width, resizeHeight: height)
    return webPData
    }
    
    #endif
    
    #if os(iOS)
    
    public func encode(_ image: UIImage, config: WebPConfig, width: Int = 0, height: Int = 0) throws -> Data {
        //        let cgImage = image.cgImage!
        // let dataPtr: UnsafeMutablePointer<UInt8>? = nil
        //        let context = CGContext(data: dataPtr, width: Int(image.size.width), height: Int(image.size.width), bitsPerComponent: 8, bytesPerRow: 8, space: cgImage.colorSpace!, bitmapInfo: cgImage.bitmapInfo.rawValue)!
        //        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        var data = UIImagePNGRepresentation(image)!
        let webPData = try data.withUnsafeMutableBytes { (body: UnsafeMutablePointer<UInt8>) -> Data in
            let stride = Int(image.size.width) * MemoryLayout<UInt8>.size * 3 // RGB = 3byte
            let webPData = try encode(RGB: body, config: config,
                                      originWidth: Int(image.size.width), originHeight: Int(image.size.height), stride: stride,
                                      resizeWidth: width, resizeHeight: height)
            return webPData
            
        }
        return webPData
    }
    
    #endif
}