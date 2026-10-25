//
//  ProfileImage.swift
//  salattracker
//
//  Profile-picture helpers: shrink a picked photo to a small square JPEG before
//  upload, and a reusable circular avatar that shows the picture when present
//  and falls back to initials when not.
//

import SwiftUI
import UIKit

enum ProfileImage {
    /// Downscale and compress picked image data into a small square JPEG,
    /// keeping avatars tiny to store and sync. Returns nil if the data isn't
    /// a decodable image.
    static func jpeg(from data: Data, maxDimension: CGFloat = 256, quality: CGFloat = 0.7) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        // Crop to a centered square, then scale down to maxDimension.
        let side = min(image.size.width, image.size.height)
        let origin = CGPoint(x: (image.size.width - side) / 2, y: (image.size.height - side) / 2)
        let target = min(maxDimension, side)

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: target, height: target), format: format)
        let square = renderer.image { _ in
            image.draw(in: CGRect(x: -origin.x / side * target,
                                  y: -origin.y / side * target,
                                  width: image.size.width / side * target,
                                  height: image.size.height / side * target))
        }
        return square.jpegData(compressionQuality: quality)
    }
}

/// A circular avatar: shows the profile picture when `imageData` decodes,
/// otherwise the person's initials on a tinted circle.
struct AvatarView: View {
    let initials: String
    var imageData: Data? = nil
    var size: CGFloat = 42
    var filled: Bool = false

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(filled ? .white : Theme.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(filled ? AnyShapeStyle(Theme.primary) : AnyShapeStyle(Theme.primary.opacity(0.15)))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
