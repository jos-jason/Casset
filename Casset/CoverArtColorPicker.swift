import SwiftUI

/// A view that displays the book's cover art and lets the user tap to pick a color from it.
struct CoverArtColorPicker: View {
    let image: UIImage
    @Binding var selectedColor: Color
    @Environment(\.dismiss) private var dismiss

    @State private var pickedColor: Color = .white
    @State private var touchLocation: CGPoint? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Tap on the cover art to pick a color")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            GeometryReader { imgGeo in
                                Color.clear
                                    .contentShape(Rectangle())
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                let location = value.location
                                                touchLocation = location
                                                if let color = colorAt(
                                                    point: location,
                                                    in: imgGeo.size,
                                                    image: image
                                                ) {
                                                    pickedColor = color
                                                }
                                            }
                                            .onEnded { value in
                                                let location = value.location
                                                touchLocation = location
                                                if let color = colorAt(
                                                    point: location,
                                                    in: imgGeo.size,
                                                    image: image
                                                ) {
                                                    pickedColor = color
                                                }
                                            }
                                    )
                                    .overlay {
                                        if let loc = touchLocation {
                                            Circle()
                                                .fill(pickedColor)
                                                .frame(width: 36, height: 36)
                                                .overlay(
                                                    Circle()
                                                        .strokeBorder(.white, lineWidth: 3)
                                                )
                                                .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                                                .position(x: loc.x, y: loc.y - 44)
                                        }
                                    }
                            }
                        )
                }

                // Selected color preview
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(pickedColor)
                        .frame(width: 50, height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.primary.opacity(0.3), lineWidth: 1)
                        )

                    VStack(alignment: .leading) {
                        Text("Selected Color")
                            .font(.headline)
                        Text("Tap the image to change")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Pick from Cover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Color") {
                        selectedColor = pickedColor
                        dismiss()
                    }
                }
            }
            .onAppear {
                pickedColor = selectedColor
            }
        }
    }

    /// Sample the color at a tap point relative to the displayed image size.
    private func colorAt(point: CGPoint, in viewSize: CGSize, image: UIImage) -> Color? {
        guard let cgImage = image.cgImage else { return nil }

        // Compute the fitted image rect within the view
        let imageAspect = CGFloat(cgImage.width) / CGFloat(cgImage.height)
        let viewAspect = viewSize.width / viewSize.height

        let fittedSize: CGSize
        if imageAspect > viewAspect {
            fittedSize = CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
        } else {
            fittedSize = CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
        }

        let offsetX = (viewSize.width - fittedSize.width) / 2
        let offsetY = (viewSize.height - fittedSize.height) / 2

        // Convert tap point to image coordinates
        let relX = (point.x - offsetX) / fittedSize.width
        let relY = (point.y - offsetY) / fittedSize.height

        guard relX >= 0, relX <= 1, relY >= 0, relY <= 1 else { return nil }

        let pixelX = Int(relX * CGFloat(cgImage.width))
        let pixelY = Int(relY * CGFloat(cgImage.height))

        // Sample a small area for a smoother color
        let sampleSize = 5
        let startX = max(0, pixelX - sampleSize / 2)
        let startY = max(0, pixelY - sampleSize / 2)
        let cropW = min(sampleSize, cgImage.width - startX)
        let cropH = min(sampleSize, cgImage.height - startY)

        guard cropW > 0, cropH > 0,
              let cropped = cgImage.cropping(to: CGRect(x: startX, y: startY, width: cropW, height: cropH))
        else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData = [UInt8](repeating: 0, count: cropW * cropH * 4)
        guard let context = CGContext(
            data: &pixelData,
            width: cropW,
            height: cropH,
            bitsPerComponent: 8,
            bytesPerRow: cropW * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cropped, in: CGRect(x: 0, y: 0, width: cropW, height: cropH))

        var totalR: CGFloat = 0
        var totalG: CGFloat = 0
        var totalB: CGFloat = 0
        let count = cropW * cropH
        for i in 0..<count {
            let off = i * 4
            totalR += CGFloat(pixelData[off]) / 255.0
            totalG += CGFloat(pixelData[off + 1]) / 255.0
            totalB += CGFloat(pixelData[off + 2]) / 255.0
        }

        return Color(
            red: totalR / CGFloat(count),
            green: totalG / CGFloat(count),
            blue: totalB / CGFloat(count)
        )
    }
}
