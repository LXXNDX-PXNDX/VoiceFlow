#include "WhisperC.h"
#include "whisper.h"
#include <string.h>
#include <stdio.h>

const char* whisperc_version(void) {
    return whisper_version();
}

WhisperCtx whisperc_init(const char* model_path) {
    if (!model_path || model_path[0] == '\0') return NULL;

    struct whisper_context_params cparams = whisper_context_default_params();
    cparams.use_gpu = true;
    cparams.flash_attn = true;
    cparams.dtw_token_timestamps = false;

    struct whisper_context* ctx = whisper_init_from_file_with_params(model_path, cparams);
    if (!ctx) {
        fprintf(stderr, "[WhisperC] GPU initialization failed; retrying with CPU fallback\n");
        cparams.use_gpu = false;
        cparams.flash_attn = false;
        ctx = whisper_init_from_file_with_params(model_path, cparams);
    }
    return (WhisperCtx)ctx;
}

bool whisperc_transcribe(WhisperCtx raw_ctx,
                         const float* samples,
                         int32_t n_samples,
                         const char* language,
                         int32_t n_threads,
                         int32_t mode,
                         int32_t audio_duration_ms,
                         const char* initial_prompt,
                         char* out_text,
                         int32_t out_max_len) {
    struct whisper_context* ctx = (struct whisper_context*)raw_ctx;
    if (!ctx || !samples || n_samples <= 0 || !out_text || out_max_len < 2) return false;

    out_text[0] = '\0';

    const bool precise = mode == 2;
    const enum whisper_sampling_strategy strategy = precise
        ? WHISPER_SAMPLING_BEAM_SEARCH
        : WHISPER_SAMPLING_GREEDY;

    struct whisper_full_params params = whisper_full_default_params(strategy);
    params.print_progress   = false;
    params.print_special    = false;
    params.print_realtime   = false;
    params.print_timestamps = false;
    params.no_timestamps    = true;
    params.translate        = false;
    params.no_context       = true;
    params.single_segment   = audio_duration_ms > 0 && audio_duration_ms <= 30000;
    params.suppress_blank   = true;
    params.suppress_nst     = true;
    params.temperature      = 0.0f;
    params.temperature_inc  = precise ? 0.2f : 0.0f;
    params.entropy_thold    = 2.4f;
    params.logprob_thold    = -1.0f;
    params.no_speech_thold  = 0.55f;
    params.greedy.best_of   = 1;
    params.beam_search.beam_size = precise ? 3 : 1;
    params.beam_search.patience = precise ? 1.0f : 0.0f;
    params.n_threads        = n_threads > 0 ? n_threads : 4;

    if (initial_prompt && initial_prompt[0] != '\0') {
        params.initial_prompt = initial_prompt;
    }

    if (language && language[0] != '\0' && strcmp(language, "auto") != 0) {
        params.language = language;
        params.detect_language = false;
    } else {
        params.language = NULL;
        params.detect_language = true;
    }

    whisper_reset_timings(ctx);
    if (whisper_full(ctx, params, samples, n_samples) != 0) {
        return false;
    }

    const int n_segments = whisper_full_n_segments(ctx);
    size_t used = 0;
    const size_t capacity = (size_t)out_max_len - 1;

    for (int i = 0; i < n_segments; i++) {
        const char* seg = whisper_full_get_segment_text(ctx, i);
        if (!seg) continue;

        size_t len = strlen(seg);
        if (len > capacity - used) len = capacity - used;
        if (len == 0) break;

        memcpy(out_text + used, seg, len);
        used += len;
        out_text[used] = '\0';

        if (used >= capacity) break;
    }

    return true;
}

void whisperc_free(WhisperCtx ctx) {
    if (ctx) {
        whisper_free((struct whisper_context*)ctx);
    }
}
