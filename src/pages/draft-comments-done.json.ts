// 2026-11-15: 下書きコメントの「対応済みの時刻」を、古い版（ハッシュ付きのプレビュー）からも読めるように JSON で出す。
// コメントは書いたアドレスのブラウザに残るため、古い版を開いたままだと対応済みのコメントが消えなかった。
import doneData from '../data/draft-comments-done.json';
export const prerender = true;
export function GET() {
  return new Response(JSON.stringify((doneData as { done: Record<string, string> }).done), {
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}
