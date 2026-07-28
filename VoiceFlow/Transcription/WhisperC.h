#ifndef WhisperC_h
#define WhisperC_h

#include <stdbool.h>
#include <stdint.h>

typedef void* WhisperCtx;

WhisperCtx whisperc_init(const char* model_path);

// language: "auto" or NULL for auto-detect, otherwise an ISO code like "de" / "en".
// mode: 0 = automatic, 1 = instant, 2 = precise.
// initial_prompt: optional vocabulary/context hint; may be NULL or empty.
// Returns false on failure. out_text is always NUL-terminated when true is returned.
bool whisperc_transcribe(WhisperCtx ctx,
                         const float* samples,
                         int32_t n_samples,
                         const char* language,
                         int32_t n_threads,
                         int32_t mode,
                         int32_t audio_duration_ms,
                         const char* initial_prompt,
                         char* out_text,
                         int32_t out_max_len);

void whisperc_free(WhisperCtx ctx);

#endif
