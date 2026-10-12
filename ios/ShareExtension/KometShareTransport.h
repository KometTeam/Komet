#ifndef KOMET_SHARE_TRANSPORT_H
#define KOMET_SHARE_TRANSPORT_H

typedef void (*KometShareProgress)(const char *json, void *context);
char *komet_share_send(const char *json, KometShareProgress progress, void *context);
void komet_share_free(char *value);

#endif
