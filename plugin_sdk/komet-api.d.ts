declare module 'komet:api' {
  export type Permission =
    | 'chat.write'
    | 'chat.edit'
    | 'chat.photo'
    | 'chat.file'
    | 'ui.notify'
    | 'contact.read'
    | 'message.readReply'
    | 'network'
    | 'storage';

  export type AttachmentType =
    | 'photo'
    | 'video'
    | 'audio'
    | 'file'
    | 'contact'
    | 'location'
    | 'sticker'
    | 'control'
    | 'poll'
    | 'share'
    | 'call'
    | 'inlineKeyboard'
    | 'forward'
    | 'unknown';

  export interface ReplyMessage {
    readonly id: string;
    readonly senderId: number;
    readonly text: string | null;
    readonly time: number;
    readonly attachments: ReadonlyArray<{ readonly type: AttachmentType }>;
  }

  export interface CommandContext {
    readonly args: string;
    readonly arguments: Readonly<Record<string, string>>;
    readonly reply: ReplyMessage | null;
    readonly apiVersion: number;
  }

  export type CommandHandler = (context: CommandContext) => void | Promise<void>;

  export type MediaSource =
    | { readonly base64: string; readonly url?: string }
    | { readonly url: string; readonly base64?: string };

  export type PhotoOptions = MediaSource & {
    readonly filename?: string;
    readonly caption?: string;
  };

  export type FileOptions = MediaSource & {
    readonly filename?: string;
  };

  export interface Peer {
    readonly id: number;
    readonly displayName: string;
    readonly country: string | null;
    readonly registrationTime: number | null;
    readonly updateTime: number | null;
    readonly options: ReadonlyArray<string>;
  }

  export type HttpMethod = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

  export interface FetchOptions {
    readonly method?: HttpMethod;
    readonly headers?: Readonly<Record<string, string>>;
    readonly body?: string;
  }

  export interface FetchResponse {
    readonly status: number;
    readonly headers: Readonly<Record<string, string>>;
    readonly body: string;
    readonly base64: string;
  }

  export type JsonValue =
    | null
    | boolean
    | number
    | string
    | JsonValue[]
    | { [key: string]: JsonValue };

  export const chat: {
    sendText(text: string): Promise<string>;
    editText(messageId: string, text: string): Promise<void>;
    sendPhoto(options: PhotoOptions): Promise<void>;
    sendFile(options: FileOptions): Promise<void>;
  };

  export const network: {
    fetch(url: string, options?: FetchOptions): Promise<FetchResponse>;
  };

  export const ui: {
    notify(message: string): Promise<void>;
  };

  export const contact: {
    getPeer(): Promise<Peer | null>;
  };

  export const runtime: {
    sleep(milliseconds: number): Promise<void>;
    isOnline(): Promise<boolean>;
    isActive(): Promise<boolean>;
  };

  export const storage: {
    get(key: string): Promise<JsonValue>;
    set(key: string, value: JsonValue): Promise<void>;
    remove(key: string): Promise<void>;
  };
}
