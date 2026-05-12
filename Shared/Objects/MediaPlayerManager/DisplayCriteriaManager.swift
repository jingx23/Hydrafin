//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

#if os(tvOS)
import AVKit
import CoreMedia
import JellyfinAPI
import UIKit

/// Switches the Apple TV's HDMI output mode (refresh rate + dynamic range)
/// to match the content being played. Without this, tvOS's compositor
/// downsamples the Metal layer's HDR output to whatever the TV is currently
/// configured for — usually SDR — and you never see the TV switch into HDR
/// mode (so the display doesn't brighten on highlights).
///
/// Apple TV Settings → Video and Audio → Match Content must allow this
/// (Match Dynamic Range, Match Frame Rate).
///
/// Approach adapted from the Moonfin tvOS project.
@MainActor
final class DisplayCriteriaManager {

    static let shared = DisplayCriteriaManager()
    private init() {}

    /// Tells tvOS to switch the HDMI output to match this video stream.
    func apply(videoStream: MediaStream) {
        guard let window = activeWindow() else { return }
        let manager = window.avDisplayManager
        guard manager.isDisplayCriteriaMatchingEnabled else { return }
        guard let criteria = buildCriteria(videoStream: videoStream) else { return }
        manager.preferredDisplayCriteria = criteria
    }

    /// Returns the HDMI output to system default. Call when playback ends.
    func reset() {
        guard let window = activeWindow() else { return }
        window.avDisplayManager.preferredDisplayCriteria = nil
    }

    private func activeWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows
            .first { $0.isKeyWindow }
    }

    private func buildCriteria(videoStream: MediaStream) -> AVDisplayCriteria? {
        guard #available(tvOS 17.0, *) else { return nil }

        let fps = videoStream.realFrameRate
            ?? videoStream.averageFrameRate
            ?? 24

        guard let formatDescription = makeFormatDescription(videoStream: videoStream) else {
            return nil
        }
        return AVDisplayCriteria(refreshRate: fps, formatDescription: formatDescription)
    }

    private func makeFormatDescription(videoStream: MediaStream) -> CMVideoFormatDescription? {
        let codecType = resolveCodecType(
            codec: videoStream.codec,
            rangeType: videoStream.videoRangeType
        )
        let width = Int32(videoStream.width ?? 3840)
        let height = Int32(videoStream.height ?? 2160)
        let extensions = makeColorExtensions(rangeType: videoStream.videoRangeType)

        var formatDescription: CMVideoFormatDescription?
        let status = CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: codecType,
            width: width,
            height: height,
            extensions: extensions,
            formatDescriptionOut: &formatDescription
        )
        guard status == noErr else { return nil }
        return formatDescription
    }

    private func resolveCodecType(
        codec: String?,
        rangeType: VideoRangeType?
    ) -> CMVideoCodecType {
        // Any DV variant — even DV-with-SDR — needs to be advertised as DV so
        // tvOS picks the DV-capable output mode (and the TV switches to DV).
        if let rangeType, Self.isDolbyVision(rangeType) {
            return kCMVideoCodecType_DolbyVisionHEVC
        }
        switch codec?.lowercased() {
        case "hevc", "h265":
            return kCMVideoCodecType_HEVC
        case "av1":
            return kCMVideoCodecType_AV1
        case "vp9":
            return kCMVideoCodecType_VP9
        default:
            return kCMVideoCodecType_H264
        }
    }

    private func makeColorExtensions(rangeType: VideoRangeType?) -> CFDictionary {
        var dict: [CFString: CFString] = [:]

        switch rangeType {
        case .hdr10?, .hdr10Plus?,
             .dovi?, .doviWithHDR10?, .doviWithHDR10Plus?, .doviWithELHDR10Plus?:
            dict[kCMFormatDescriptionExtension_ColorPrimaries] = kCMFormatDescriptionColorPrimaries_ITU_R_2020
            dict[kCMFormatDescriptionExtension_TransferFunction] = kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ
            dict[kCMFormatDescriptionExtension_YCbCrMatrix] = kCMFormatDescriptionYCbCrMatrix_ITU_R_2020

        case .hlg?, .doviWithHLG?:
            dict[kCMFormatDescriptionExtension_ColorPrimaries] = kCMFormatDescriptionColorPrimaries_ITU_R_2020
            dict[kCMFormatDescriptionExtension_TransferFunction] = kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG
            dict[kCMFormatDescriptionExtension_YCbCrMatrix] = kCMFormatDescriptionYCbCrMatrix_ITU_R_2020

        default:
            // .sdr, .doviWithSDR, .unknown, .doviInvalid, .none, .doviWithEL: SDR output, no color extensions.
            break
        }

        return dict as CFDictionary
    }

    private static func isDolbyVision(_ rangeType: VideoRangeType) -> Bool {
        switch rangeType {
        case .dovi, .doviWithSDR, .doviWithHDR10, .doviWithHDR10Plus,
             .doviWithEL, .doviWithELHDR10Plus, .doviWithHLG:
            true
        default:
            false
        }
    }
}
#endif
