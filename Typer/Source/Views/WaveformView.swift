import SwiftUI

struct WaveformView: View {
    let samples: [CGFloat]

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0 ..< samples.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(
                            width: (geometry.size.width / CGFloat(samples.count)) - 2,
                            height: geometry.size.height * samples[index]
                        )
                        .frame(height: geometry.size.height, alignment: .center)
                        .animation(.easeOut(duration: 0.1), value: samples[index])
                }
            }
        }
    }
}
