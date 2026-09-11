---
status: accepted
date: 2026-09-11
---

# skill と agent 定義を単一 plugin で配布する

agent-gears は、すべての skill と Claude Code 用 agent 定義を `plugins/agent-gears/` の単一 plugin で配布する。
用途別の分類は説明上のまとまりとして残すが、plugin の境界にはしない。
Claude marketplace は、nix を使えない host や checkout のない環境への配布経路として維持する。

## なぜ

第一の利用経路である Home Manager は、plugin の境界にかかわらず全 skill を平坦に配布する。
`install.sh` も同じであり、7分割された plugin を個別に導入する利用者を想定した境界には実際の役割がなかった。

一方で、分割は marketplace と plugin のメタデータ、README の install 手順、第三者由来 skill の plugin 単位の帰属表示を重複させていた。
単一 plugin なら marketplace 経路を残しながら、この同期コストと帰属表示の分散を除ける。

## Considered options

- 7つの plugin を維持する。
- marketplace 経路を廃止し、Home Manager と `install.sh` だけにする。
- marketplace 経路を維持し、配布単位を単一の `agent-gears` plugin にする。

三つ目を採用した。

## Consequences

Claude marketplace からは `agent-gears@fenril058-agent-skills` を1つ導入する。
旧7 plugin の名前は残さないため、既存の marketplace 利用者は新しい plugin を入れ直す必要がある。

`install.sh` と `nix/hm-module.nix` は `plugins/<plugin>/skills/*` と `plugins/<plugin>/agents/*` を総称的に列挙しており、単一 plugin でも同じ配布先を生成するため変更しない。
plugin 単位の第三者 MIT 許諾文と public domain の出典表示は `plugins/agent-gears/` に集約し、skill 単位の `LICENSE` は各 skill に残す。

`search.md` の存廃は issue #83 の判断に委ね、この決定では扱わない。
plugin の集約を generic routing、hook、context-control、cheap-worker framework の導入理由にはしない。
