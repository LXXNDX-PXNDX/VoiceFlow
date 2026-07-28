#include "WhisperC.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char ** argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: whisper-smoke-test MODEL\n");
        return 64;
    }

    const char * version = whisperc_version();
    if (!version || strstr(version, "1.8.6") == NULL) {
        fprintf(stderr, "unexpected whisper.cpp runtime: %s\n", version ? version : "null");
        return 65;
    }

    WhisperCtx context = whisperc_init(argv[1]);
    if (!context) {
        fprintf(stderr, "could not load smoke-test model\n");
        return 66;
    }

    const int sample_count = 32000;
    float * samples = calloc((size_t) sample_count, sizeof(float));
    if (!samples) {
        whisperc_free(context);
        return 67;
    }

    char output[4096];
    const bool ok = whisperc_transcribe(
        context,
        samples,
        sample_count,
        "en",
        4,
        1,
        2000,
        "",
        output,
        (int32_t) sizeof(output)
    );

    printf("whisper.cpp %s, transcription call: %s, output: %s\n",
           version,
           ok ? "ok" : "failed",
           output);

    free(samples);
    whisperc_free(context);
    return ok ? 0 : 68;
}
