//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import AVFoundation
import VideoToolbox

enum PlaybackCapabilities {

    /// This property is true if an HDR display is available and the device is capable of playing HDR content from an appropriate AVAsset,
    /// false otherwise.
    static var isDeviceHDRCapable: Bool {
        AVPlayer.eligibleForHDRPlayback
    }

    /// Should Swiftfin handle Dolby Vision content (false) or should it be tone mapped by the server (true)?
    static var dvEnabled: Bool {
        !StoredValues[.User.forceDVTranscode]
    }

    /// Should Swiftfin handle HDR content (false) or should it be tone mapped by the server (true)?
    static var hdrEnabled: Bool {
        !StoredValues[.User.forceHDRTranscode]
    }

    static var gpuName: String {
        MTLCreateSystemDefaultDevice()?.name ?? L10n.unknown
    }

    /// Heuristic for "this device has the memory bandwidth to drive a 4K HDR
    /// drawable (rgba16Float / Rec.2100 PQ) without dropping frames".
    ///
    /// On iOS, 6 GB+ RAM correlates with iPhone 13 Pro and newer (Pro line and
    /// the iPhone 15+ baseline). Below this threshold — iPhone SE3, iPad mini 6,
    /// base 13/14 — the rgba16Float swapchain consumes too much of the GPU
    /// memory budget when driving an external 4K HDR display.
    ///
    /// On tvOS, every supported Apple TV outputs to a TV (always potentially
    /// HDR), so we always engage the HDR pipeline. Caller is responsible for
    /// avoiding the *expensive* shaders separately — even A15 Apple TV 4K
    /// can't sustain ewa_lanczos / hdr-compute-peak at 4K.
    static var isHighPerformanceVideo: Bool {
        #if os(tvOS)
        return true
        #else
        return ProcessInfo.processInfo.physicalMemory >= UInt64(6) * 1024 * 1024 * 1024
        #endif
    }

    // MARK: - Hardware Decode

    // MARK: MPEG / ITU-T

    /// Returns true if the device supports hardware-accelerated H.264/AVC decoding.
    static var supportsH264: Bool {
        VTIsHardwareDecodeSupported(kCMVideoCodecType_H264)
    }

    /// Returns true if the device supports hardware-accelerated H.265/HEVC decoding.
    static var supportsHEVC: Bool {
        VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)
    }

    // MARK: Alliance for Open Media

    /// Returns true if the device supports hardware-accelerated AV1 decoding.
    /// Requires A17 Pro / M3 or newer.
    static var supportsAV1: Bool {
        VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)
    }

    // MARK: Google

    /// Returns true if the device supports hardware-accelerated VP9 decoding.
    /// Note: VP9 hardware decode is not available on iOS/tvOS.
    static var supportsVP9: Bool {
        VTIsHardwareDecodeSupported(kCMVideoCodecType_VP9)
    }

    // MARK: - HDR

    /// Returns true if the device can play HDR10 content.
    /// Requires HEVC hardware decode AND HDR-capable display.
    /// Note: HDR10 is a transfer function, not a codec—the underlying codec is HEVC.
    static var supportsHDR10: Bool {
        supportsHEVC && hdrEnabled
    }

    /// Returns true if the device can play HLG content.
    /// Requires HEVC hardware decode AND HDR-capable display.
    /// Note: HLG is a transfer function, not a codec—the underlying codec is HEVC.
    static var supportsHLG: Bool {
        supportsHEVC && hdrEnabled
    }

    /// Returns true if the device supports hardware-accelerated Dolby Vision HEVC decoding.
    /// This correctly distinguishes A10 (no DV) from A10X (DV support).
    static var supportsDolbyVision: Bool {
        VTIsHardwareDecodeSupported(kCMVideoCodecType_DolbyVisionHEVC) && dvEnabled
    }
}
