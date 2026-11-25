import AppKit
import ImageIO
import CoreText
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
    static func pictureText(_ text:String)->String {
        String(text.map { $0.isNewline ? " " : $0 }.prefix(8))
    }
    /// Theme-independent picture bytes, shared by the preview and the upload.
    static func letterPicture(color:UserBubbleColor,text:String) throws -> Data {
        let palette=UserBubblePalette(color:color,dark:false)
        guard let context=CGContext(data:nil,width:256,height:256,bitsPerComponent:8,bytesPerRow:0,
                                    space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else {throw FileTransferFailure.invalidFile}
        let square=CGRect(x:0,y:0,width:256,height:256),safe=square.insetBy(dx:256*0.18,dy:256*0.18)
        context.setFillColor(palette.background.nsColor.cgColor);context.fill(square)
        let letters=pictureText(text)
        if !letters.isEmpty {
            var size:CGFloat=180
            while size>=1 {
                let attributes:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:size,weight:.bold),.foregroundColor:palette.foreground.nsColor]
                let line=CTLineCreateWithAttributedString(NSAttributedString(string:letters,attributes:attributes))
                let bounds=CTLineGetBoundsWithOptions(line,[.useGlyphPathBounds])
                if bounds.width<=safe.width && bounds.height<=safe.height {
                    guard let lettersContext=CGContext(data:nil,width:256,height:256,bitsPerComponent:8,bytesPerRow:0,
                                                       space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else {throw FileTransferFailure.invalidFile}
                    lettersContext.textPosition=CGPoint(x:square.midX-bounds.midX,y:square.midY-bounds.midY)
                    CTLineDraw(line,lettersContext)
                    // Use glyph alpha so even color emoji follows the same black/white rule.
                    guard let mask=lettersContext.makeImage() else {throw FileTransferFailure.invalidFile}
                    context.saveGState();context.clip(to:safe);context.clip(to:square,mask:mask)
                    context.setFillColor(palette.foreground.nsColor.cgColor);context.fill(square)
                    context.restoreGState();break
                }
                size-=1
            }
        }
        let out=NSMutableData()
        guard let image=context.makeImage(),let writer=CGImageDestinationCreateWithData(out,UTType.png.identifier as CFString,1,nil) else {throw FileTransferFailure.invalidFile}
        CGImageDestinationAddImage(writer,image,nil)
        guard CGImageDestinationFinalize(writer) else {throw FileTransferFailure.invalidFile}
        guard out.length<=maximum else {throw FileTransferFailure.tooLarge};return out as Data
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

/// Disposable attachment previews. Cells share the same image; weak entries account for
/// images still displayed after cache eviction without extending their lifetime.
@MainActor final class AttachmentThumbnailCache {
    static let maximumPixelSize = 512
    private final class Entry {
        weak var image:NSImage?
        let bytes:Int
        init(_ image:NSImage,bytes:Int) {self.image=image;self.bytes=bytes}
    }
    private var cached:[String:NSImage]=[:],entries:[String:Entry]=[:],order:[String]=[]
    let byteLimit:Int
    init(byteLimit:Int=16*1024*1024) {self.byteLimit=max(0,byteLimit)}
    var cachedBytes:Int {cached.keys.reduce(0) {$0+(entries[$1]?.bytes ?? 0)}}
    var retainedBytes:Int {entries.values.reduce(0) {$0+($1.image == nil ? 0:$1.bytes)}}
    var displayedExcessBytes:Int {max(0,retainedBytes-byteLimit)}
    func image(_ id:String)->NSImage? {
        guard let image=entries[id]?.image else {return nil}
        if cached[id] != nil {order.removeAll {$0==id};order.append(id)}
        return image
    }
    func removeAll() {cached.removeAll();entries.removeAll();order.removeAll()}
    @discardableResult func load(_ url:URL,id:String) throws -> NSImage {
        if let existing=image(id) {return existing}
        guard let source=CGImageSourceCreateWithURL(url as CFURL,[kCGImageSourceShouldCache:false] as CFDictionary),
              let thumbnail=CGImageSourceCreateThumbnailAtIndex(source,0,[
                kCGImageSourceCreateThumbnailFromImageAlways:true,
                kCGImageSourceCreateThumbnailWithTransform:true,
                kCGImageSourceThumbnailMaxPixelSize:Self.maximumPixelSize,
                kCGImageSourceShouldCacheImmediately:true] as CFDictionary),
              thumbnail.width<=Self.maximumPixelSize,thumbnail.height<=Self.maximumPixelSize,
              let context=CGContext(data:nil,width:thumbnail.width,height:thumbnail.height,bitsPerComponent:8,
                bytesPerRow:thumbnail.width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,
                bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else {throw FileTransferFailure.invalidFile}
        context.draw(thumbnail,in:CGRect(x:0,y:0,width:thumbnail.width,height:thumbnail.height))
        guard let bitmap=context.makeImage() else {throw FileTransferFailure.invalidFile}
        let image=NSImage(cgImage:bitmap,size:CGSize(width:bitmap.width,height:bitmap.height))
        entries=entries.filter {$0.value.image != nil}
        entries[id]=Entry(image,bytes:bitmap.bytesPerRow*bitmap.height)
        cached[id]=image;order.append(id)
        while cachedBytes>byteLimit || cached.count>128 {
            let oldest=order.removeFirst();cached.removeValue(forKey:oldest)
        }
        return image
    }
}
