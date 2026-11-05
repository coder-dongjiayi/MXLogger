export interface NativeHandle { readonly owned: boolean; }
export const initialize: (ns: string, directory: string, policy: string, filename: string,
  header: string, key: string, iv: string) => NativeHandle;
export const attach: (token: string) => NativeHandle;
export const coreVersion: () => string;
export const log: (handle: NativeHandle, level: number, message: string, name: string, tag: string) => number;
export const logWithToken: (token: string, level: number, message: string, name: string, tag: string) => number;
export const configure: (handle: NativeHandle, option: number, value: number) => void;
export const snapshot: (handle: NativeHandle) => string;
export const files: (handle: NativeHandle) => string;
export const read: (handle: NativeHandle, filename: string) => string;
export const isValid: (handle: NativeHandle) => boolean;
export const destroy: (handle: NativeHandle) => void;
export const flush: (handle: NativeHandle) => void;
export const clean: (handle: NativeHandle, mode: number) => void;
