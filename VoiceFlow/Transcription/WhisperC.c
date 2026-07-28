#include "WhisperC.h"
#include "whisper.h"
#include <string.h>
#include <stdio.h>

WhisperCtx whisperc_init(const char* model_path) {
    struct whisper_context_params cparams = whisper_context_default_params();
    cparams.use_gpu = true;
    struct whisper_context* ctx = whisper_init_from_file_with_params(model_path, cparams);
    return (WhisperCtx)ctx;
}

bool whisperc_transcribe(WhisperCtx raw_ctx,
                         const float* samples,
                         int32_t n_samples,
                         const char* language,
                         int32_t n_threads,
                         char* out_text,
                         int32_t out_max_len) {
    struct whisper_context* ctx = (struct whisper_context*)raw_ctx;
    if (!ctx || !samples || n_samples <= 0 || !out_text || out_max_len < 2) return false;

    out_text[0] = '\0';

    struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.print_progress   = false;
    params.print_special    = false;
    params.print_realtime   = false;
    params.print_timestamps = false;
    params.translate        = false;
    params.no_context       = true;
    params.single_segment   = false;
    params.suppress_blank   = true;
    params.suppress_nst     = true;
    params.temperature      = 0.0f;
    params.greedy.best_of   = 1;
    params.n_threads        = n_threads > 0 ? n_threads : 4;

    // NULL / "auto" makes whisper.cpp run its own language detection.
    if (language && language[0] != '\0' && strcmp(language, "auto") != 0) {
        params.language = language;
        params.detect_language = false;
    } else {
        params.language = NULL;
        params.detect_language = true;
    }

    if (whisper_full(ctx, params, samples, n_samples) != 0) {
        return false;
    }

    const int n_segments = whisper_full_n_segments(ctx);
    size_t used = 0;                                  // bytes written, excluding terminator
    const size_t capacity = (size_t)out_max_len - 1;  // reserve room for the terminator

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
