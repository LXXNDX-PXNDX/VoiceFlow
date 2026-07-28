#ifndef WhisperC_h
#define WhisperC_h

#include <stdbool.h>
#include <stdint.h>

typedef void* WhisperCtx;

WhisperCtx whisperc_init(const char* model_path);

// language: "auto" or NULL for auto-detect, otherwise an ISO code like "de" / "en".
// Returns false on failure. out_text is always NUL-terminated when true is returned.
bool whisperc_transcribe(WhisperCtx ctx,
                         const float* samples,
                         int32_t n_samples,
                         const char* language,
                         int32_t n_threads,
                         char* out_text,
                         int32_t out_max_len);

void whisperc_free(WhisperCtx ctx);

#endif
