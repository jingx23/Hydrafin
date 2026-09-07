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
/// Moonfin's original fix returns stereo here, which collapses a 7.1.4 Atmos
/// bed to two channels. Hydrafin instead reports the layout matching the
/// current route's channel count (see setAudioUnitChannelLayoutFallbackChannels),
/// so a multichannel-capable receiver gets multichannel PCM while a stereo-only
/// route is not asked for 8 channels it cannot take.
///
/// Idempotent and process-wide: safe to call multiple times; the rebind happens
/// once and propagates to any image loaded later via _dyld_register_func_for_add_image.
///
/// Credit: Approach adapted from the Moonfin tvOS project.
void installAudioUnitChannelLayoutFix(void);

/// Publishes the number of channels the current audio route can accept, used to
/// pick the fallback layout above.
///
/// Call before playback starts and again whenever the route changes. Until it
/// is called the fallback stays at 8 channels (MPEG 7.1). Values without a
/// natural layout fall back to stereo.
///
/// Thread-safe: the value is stored atomically and read on the audio thread.
void setAudioUnitChannelLayoutFallbackChannels(unsigned int channels);

#ifdef __cplusplus
}
#endif

#endif
