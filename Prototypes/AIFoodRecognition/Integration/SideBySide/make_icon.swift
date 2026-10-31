// Draw a new, opaque test-app icon; no production artwork is modified.
import AppKit
import Foundation

let path = CommandLine.arguments[1]
let directory = URL(fileURLWithPath: path).appendingPathComponent("SandboxIcon.appiconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
                              bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false,
                              isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(calibratedRed: 0.12, green: 0.23, blue: 0.43, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
NSColor.systemOrange.setFill()
NSBezierPath(roundedRect: NSRect(x: 140, y: 160, width: 744, height: 200), xRadius: 40, yRadius: 40).fill()
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
("AI" as NSString).draw(in: NSRect(x: 0, y: 380, width: 1024, height: 380),
                         withAttributes: [.font: NSFont.systemFont(ofSize: 340, weight: .bold),
                                          .foregroundColor: NSColor.white, .paragraphStyle: paragraph])
("TEST" as NSString).draw(in: NSRect(x: 140, y: 180, width: 744, height: 160),
                           withAttributes: [.font: NSFont.systemFont(ofSize: 132, weight: .bold),
                                            .foregroundColor: NSColor.black, .paragraphStyle: paragraph])
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("SandboxIcon.png"))
let manifest = """
{"images":[{"filename":"SandboxIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
"""
try manifest.write(to: directory.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
try "{\"info\":{\"author\":\"xcode\",\"version\":1}}".write(to: URL(fileURLWithPath: path).appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
