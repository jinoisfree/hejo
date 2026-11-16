import AppKit
import ImageIO
import UniformTypeIdentifiers

enum PictureCodec {
    static let maximum = 512*1024
    static func png(_ data: Data) throws -> Data {
        guard let source=CGImageSourceCreateWithData(data as CFData,nil), let image=CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceThumbnailMaxPixelSize:2048] as CFDictionary) else { throw FileTransferFailure.invalidFile }
        let edge=min(image.width,image.height), rect=CGRect(x:(image.width-edge)/2,y:(image.height-edge)/2,width:edge,height:edge)
        guard let crop=image.cropping(to:rect), let context=CGContext(data:nil,width:256,height:256,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { throw FileTransferFailure.invalidFile }
        context.interpolationQuality = .high; context.draw(crop,in:CGRect(x:0,y:0,width:256,height:256))
        let out=NSMutableData()
        guard let resized=context.makeImage(),let writer=CGImageDestinationCreateWithData(out,UTType.png.identifier as CFString,1,nil) else { throw FileTransferFailure.invalidFile }
        CGImageDestinationAddImage(writer,resized,nil)
        guard CGImageDestinationFinalize(writer) else { throw FileTransferFailure.invalidFile }
        guard out.length<=maximum else { throw FileTransferFailure.tooLarge };return out as Data
    }
    static func color(name: String, hex: String?) -> NSColor {
        if let hex,hex.count==7,hex.first=="#",let value=UInt32(hex.dropFirst(),radix:16) {
            return NSColor(srgbRed:CGFloat((value>>16)&255)/255,green:CGFloat((value>>8)&255)/255,blue:CGFloat(value&255)/255,alpha:1)
        }
        let hash=name.utf8.reduce(UInt32(5381)) { ($0 &* 33) &+ UInt32($1) }
        let hue=Double(hash%360)/60, chroma=0.9*0.6, x=chroma*(1-abs(hue.truncatingRemainder(dividingBy:2)-1)), m=0.55-chroma/2
        let values:[(Double,Double,Double)]=[(chroma,x,0),(x,chroma,0),(0,chroma,x),(0,x,chroma),(x,0,chroma),(chroma,0,x)]
        let rgb=values[Int(hue)%6]
        return NSColor(srgbRed:rgb.0+m,green:rgb.1+m,blue:rgb.2+m,alpha:1)
    }
}

/// Authenticated address-keyed memory cache. It never writes image bytes to local settings.
@MainActor final class PictureCache {
    let http: GateHTTP
    private var images: [String:NSImage] = [:], fetching=Set<String>(), failed=Set<String>()
    private var identity=""
    private var generation=0
    func invalidate() { generation += 1;images=[:];fetching=[];failed=[] }
    var onChange:(()->Void)?
    init(http:GateHTTP) { self.http=http }
    func image(_ path:String?) -> NSImage? {
        guard http.client.bearer != nil else { invalidate();return nil }
        let scope=http.client.store.settings.address+"/"+http.client.store.settings.credentialAccount+"/"+String(http.client.connectionEpoch)+"/"+String(generation)
        if identity != scope { identity=scope;images=[:];fetching=[];failed=[] }
        guard let path else { return nil }
        if let image=images[path] { return image }
        guard !fetching.contains(path),!failed.contains(path) else { return nil }
        fetching.insert(path)
        Task { [weak self] in
            guard let self else { return }
            let data=try? await http.picture(path)
            guard scope==identity else { return }
            fetching.remove(path)
            if let data,let source=CGImageSourceCreateWithData(data as CFData,nil),
               let thumbnail=CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceThumbnailMaxPixelSize:64] as CFDictionary) {
                images[path]=NSImage(cgImage:thumbnail,size:CGSize(width:thumbnail.width,height:thumbnail.height))
            } else { failed.insert(path) }
            onChange?()
        }
        return nil
    }
}
