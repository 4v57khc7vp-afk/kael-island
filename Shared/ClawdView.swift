import SwiftUI

// Pixel Clawd, base shape from marciogranzotto/clawd-tank (MIT).
// Blue headphones added: this one is Kael.
struct ClawdView: View {
    var height: CGFloat = 20

    private struct Px { let x, y, w, h: CGFloat; let c: Color }
    private static let body = Color(red: 0xDE/255, green: 0x88/255, blue: 0x6D/255)
    private static let phone = Color(red: 0x5B/255, green: 0x8D/255, blue: 0xEF/255)
    private static let top: CGFloat = 5
    private static let rows: CGFloat = 11
    private static let cols: CGFloat = 15

    private let pixels: [Px] = [
        Px(x: 3, y: 15, w: 9, h: 1, c: .black.opacity(0.5)),
        Px(x: 2, y: 6, w: 11, h: 7, c: body),
        Px(x: 0, y: 9, w: 2, h: 2, c: body),
        Px(x: 13, y: 9, w: 2, h: 2, c: body),
        Px(x: 3, y: 13, w: 1, h: 2, c: body),
        Px(x: 5, y: 13, w: 1, h: 2, c: body),
        Px(x: 9, y: 13, w: 1, h: 2, c: body),
        Px(x: 11, y: 13, w: 1, h: 2, c: body),
        Px(x: 4, y: 8, w: 1, h: 2, c: .black),
        Px(x: 10, y: 8, w: 1, h: 2, c: .black),
        Px(x: 2, y: 5, w: 11, h: 1, c: phone),
        Px(x: 1, y: 6, w: 1, h: 3, c: phone),
        Px(x: 13, y: 6, w: 1, h: 3, c: phone)
    ]

    var body: some View {
        let u = height / Self.rows
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(0..<pixels.count, id: \.self) { i in
                let p = pixels[i]
                Rectangle()
                    .fill(p.c)
                    .frame(width: p.w * u, height: p.h * u)
                    .offset(x: p.x * u, y: (p.y - Self.top) * u)
            }
        }
        .frame(width: Self.cols * u, height: Self.rows * u, alignment: .topLeading)
    }
}
