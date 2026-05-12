//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

#ifndef AudioUnitChannelLayoutFix_h
#define AudioUnitChannelLayoutFix_h

#ifdef __cplusplus
extern "C" {
#endif

/// Patches AudioUnitGetProperty / AudioUnitGetPropertyInfo to return an
/// MPEG 7.1 fallback when CoreAudio reports an unparseable channel layout
/// (error -10879).
///
/// Dolby Atmos and some 5.1/7.1 streams cause the RemoteIO AudioUnit to return
/// an unparseable channel layout, which prevents mpv's audiounit AO from
/// initializing — manifesting as audio dropouts, A/V drift, or total silence.
///
/// Moonfin's original fix returns stereo here; Hydrafin returns 7.1 instead so
/// the bed of an Atmos source survives. CoreAudio's mixer downsamples to the
/// actual output device's capability (5.1 / stereo) — there's no loss of
/// compatibility, but multichannel-capable receivers get multichannel PCM
/// instead of a stereo downmix.
///
/// Idempotent and process-wide: safe to call multiple times; the rebind happens
/// once and propagates to any image loaded later via _dyld_register_func_for_add_image.
///
/// Credit: Approach adapted from the Moonfin tvOS project.
void installAudioUnitChannelLayoutFix(void);

#ifdef __cplusplus
}
#endif

#endif
