// Keep the bulk benchmark payload identical to the iOS / Android / macOS / Flutter demos.
export const BENCHMARK_COUNT: number = 100000;
export const BENCHMARK_NAME: string = 'benchmark';
export const BENCHMARK_TAG: string = 'perf';

export function benchmarkMessage(sequence: number): string {
  return '[' + sequence.toString().padStart(6, '0') + '] This is a benchmark loooooooooooooooooooooooooooooog';
}
