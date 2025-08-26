# 電卓レベルの言語の作成
* この章の目標は、Cコンパイラ作成の最初のステップとして `30 + (4 - 2) * 5` のような式をコンパイルできるようにすること。
* 数式には、カッコの中の式が優先される・掛け算が足し算より優先される、などの構造があって、それを何らかの方法で理解しなければ正しく計算できない。
* 入力として与えられる数式はフラットな文字の列で、構造化されたデータではない。式を正しく評価するには、文字の並びを解析して、そこに隠れた構造をうまく導き出す必要がある。
* 構文解析の最も一般的なアルゴリズムである **再帰下降構文** を使う。

## ステップ1: 整数1個をコンパイルする言語の作成
ここでは、1個の整数を入力から読んで、その数をプログラムの終了コードとして終了するアセンブリを出力するコンパイラを作る。`hcc` という名前のコンパイラを作っていく（`gcc` が主流なのでgの次のhを使うことにする）。

### コンパイラ本体の作成
コンパイラには通常はファイルを入力として与えるが、ファイルをオープンして読むのが面倒なので、コマンドの第1引数に直接コードを与えることにする。第1引数を数値として読み込んで、定型文のアセンブリの中に埋め込むCプログラムは、次のように書ける。

```c
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv)
{
    if (argc != 2) {
        fprintf(stderr, "引数の個数が正しくありません\n");
        return 1;
    }

    printf(".globl main\n");
    printf("main:\n");
    printf("  mov x0, %d\n", atoi(argv[1]));
    printf("  ret\n");
}
```

`hcc` というディレクトリを作って、その中に上記のプログラムを `hcc.c` というファイルを作成する。その後、以下のように `hcc` を実行して動作を確認する。

```shell
$ cc -o hcc hcc.c
$ ./hcc 123 > tmp.s
```

生成されるアセンブリ `tmp.s` の中身を確認する。123という数字が書き込めていることがわかる。

```shell
$ cat tmp.s
.globl main
main:
  mov x0, 123
  ret
```

**Unixにおいては、cc（あるいはgcc）はCやC++だけではなく、多くの言語のフロントエンドということになっていて、与えられたファイルの拡張子で言語を判定してコンパイラやアセンブラを起動することになっている。** したがって、ここでは `hcc` をコンパイルしたときと同じように、`.s` という拡張子のアセンブラファイルをccに渡すとアセンブルすることができる。

### 自動テストの作成
ここでは、手書きの簡単なテストフレームワークをシェルスクリプトで書いて、それを使ってテストを実行することにする。
以下は、テスト用のスクリプト `test.sh` である。関数 `assert` は入力の値と期待される出力の値という2つの引数を受け取って、実際に `hcc` の結果をアセンブルし、実際の結果を期待されている値と比較する。

```shell
#!/bin/bash
assert() {
    expected="$1"
    input="$2"

    ./hcc "$input" > tmp.s
    cc -o tmp tmp.s
    ./tmp
    actual="$?"

    if [ "$actual" = "$expected" ]; then
        echo "$input => $actual"
    else
        echo "$input => $expected expected, but got $actual"
        exit 1
    fi
}

assert 0 0
assert 42 42

echo OK
```

上記の内容で `test.sh` を作成して、`chmod a+x test.sh` を実行して実行権限を与える。実際にテストを実行してみて、何もエラーが起きなければ最後にOKを表示して終了する。

```shell
$ ./test.sh 
0 => 0
42 => 42
OK
```

テストスクリプトをデバッグしたい時は、bashに `-x` オプションをつけてスクリプトを実行する。

```shell
$ bash -x ./test.sh 
+ assert 0 0
+ expected=0
+ input=0
+ ./hcc 0
+ cc -o tmp tmp.s
+ ./tmp
+ actual=0
+ '[' 0 = 0 ']'
+ echo '0 => 0'
0 => 0
+ assert 42 42
+ expected=42
+ input=42
+ ./hcc 42
+ cc -o tmp tmp.s
+ ./tmp
+ actual=42
+ '[' 42 = 42 ']'
+ echo '42 => 42'
42 => 42
+ echo OK
OK
```

### makeによるビルド
makeは、実行されるとカレントディレクトリのMakefileを読み込んで、そこに書かれているコマンドを実行する。

```makefile
CFLAGS=-std=c11 -g -static

9cc: 9cc.c

test: 9cc
        ./test.sh

clean:
        rm -f 9cc *.o *~ tmp*

.PHONY: test clean
```

上記のファイルを、`hcc.c` と同じディレクトリに `Makefile` というファイル名で作成する。そうすると、`make` を実行するだけで実行ファイル `hcc` が作成され、`make test` を実行するとテストが実行する、ということができるようになる。


## ステップ2: 加減算のできるコンパイラの作成
ステップ1で作成したコンパイラを拡張して、42のような数値だけでなく、`2+11` や `5+20-4` のような加減算を含む式を受け取れるようにする。
コンパイルするときに計算して、その結果をアセンブラに埋め込むこともできるが、それだとインタープリタみたいになってしまうので、加減算を実行時に行うアセンブラを出力する必要がある。

```
.globl main

main:
    mov x0, 5
    add x0, x0, 20
    sub x0, x0, 4
    ret
```

上記のファイル `tmp2.s` をアセンブルすると21が表示されることが確認できる。

```shell
$ cc -o tmp2 tmp2.s
$ ./tmp2
$ echo $?
21
```

このアセンブリファイルはどう作成すればいいのか。この加減算のある式を言語として考えると、次のように定義できる。
* 最初に数字が1つある
* そのあとに0個以上の項が続いている
  * 項は、`+` または `-` のあとに数字が来ているもの

この定義を素直にCプログラムに落とし込んでみる（変更箇所のみ抜粋）

```c
char *p = argv[1];

printf(".globl main\n");
printf("main:\n");
printf("  mov x0, %ld\n", strtol(p, &p, 10));

while (*p) {
    if (*p == '+') {
        p++;
        printf("  add x0, x0, %ld\n", strtol(p, &p, 10));
        continue;
    }

    if (*p == '-') {
        p++;
        printf("  sub x0, x0, %ld\n", strtol(p, &p, 10));
        continue;
    }

    fprintf(stderr, "予期しない文字です: '%c'\n", *p);
    return 1;
}
```

今回は数字1つを読むだけではないので、数字を読み込んだあとに、どこまで読み込んだかがわからないといけない。
`atoi` では次の項をどこから読み込めばいいのかわからなくなってしまうので、ここでは `strtol` 関数を使う。
`strtol` は、数値を読み込んだあと、第2引数のポインタをアップデートして、読み込んだ最後の文字の次の文字を指すように値を更新する。なので、数値を1つ読み込んだあと、もしその次が `+` や `-` なら `p` はその次の文字を指しているはず。

このコンパイラを実行してみると、うまくアセンブリが出力されていることがわかる。

```shell
$ make
$ ./hcc '5+20-4'
.globl main
main:
  mov x0, 5
  add x0, x0, 20
  sub x0, x0, 4
  ret
```

新しい機能をテストするために、`test.sh` に `assert 21 "5+20-4"` を追加する。


## ステップ3: トークナイザを導入
ステップ2で作成したコンパイラには欠点がある。もし入力に空白文字が含まれている場合はその時点でエラーになってしまう。

```shell
$ ./hcc '5 - 3' > tmp.s
予期しない文字です: ' '
```

この問題を解決するために、式を読む前に入力を単語に分割する。

`5+20-4` は `5`, `+`, `20`, `-`, `4` という5つの単語からできていると考えることができる。この単語のことを **トークン** という。文字列をトークンに分解することをトークナイズするという。

トークナイザを導入して改良したバージョンのコンパイラを下に記載する。

<details><summary>コード</summary>

```c
#include <ctype.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// トークンの種類
typedef enum {
    TK_RESERVED,  // 記号
    TK_NUM,       // 整数トークン
    TK_EOF,       // 入力の終わりを表すトークン
} TokenKind;

typedef struct Token Token;

// トークン型
struct Token {
    TokenKind kind;  // トークンの型
    Token *next;     // 次の入力トークン
    int val;         // kindがTK_NUMの場合、その数値
    char *str;       // トークン文字列
};

// 現在着目しているトークン
Token *token;

// エラーを報告する関数(printfと同じ引数をとる)
void error(char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    fprintf(stderr, "\n");
    exit(1);
}

// 次のトークンが期待している記号のときにはトークンを1つ読み進めてtrueを返す
// それ以外の場合はfalseを返す
bool consume(char op) {
    if (token->kind != TK_RESERVED || token->str[0] != op) {
        return false;
    }

    token = token->next;
    return true;
}

// 次のトークンが期待している記号の場合、トークンを1つ読み進める
// それ以外の場合はエラーを出力する
void expect(char op) {
    if (token->kind != TK_RESERVED || token->str[0] != op) {
        error("%c ではありません", op);
    }

    token = token->next;
}

// 次のトークンが数値の場合、トークンを1つ読み進めてその数値を返す
// それ以外の場合はエラーを出力する
int expect_number() {
    if (token->kind != TK_NUM) {
        error("数ではありません");
    }

    int val = token->val;
    token = token->next;
    return val;
}

bool at_eof() {
    return token->kind == TK_EOF;
}

// 新しいトークンを作成してcurに繋げる
Token *new_token(TokenKind kind, Token *cur, char *str) {
    Token *tok = calloc(1, sizeof(Token));
    tok->kind = kind;
    tok->str = str;
    cur->next = tok;
    return tok;
}

// 入力文字列をトークナイズしてそれを返す
Token *tokenize(char *p) {
    Token head;
    head.next = NULL;
    Token *cur = &head;

    while (*p) {
        // 空白文字はスキップ
        if (isspace(*p)) {
            p++;
            continue;
        }

        if (*p == '+' || *p == '-') {
            cur = new_token(TK_RESERVED, cur, p++);
            continue;
        }

        if (isdigit(*p)) {
            cur = new_token(TK_NUM, cur, p);
            cur->val = strtol(p, &p, 10);
            continue;
        }

        error("トークナイズできません");
    }

    new_token(TK_EOF, cur, p);
    return head.next;
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        error("引数の個数が正しくありません");
        return 1;
    }

    token = tokenize(argv[1]);

    printf(".globl main\n");
    printf("main:\n");

    // 式の最初は数値でなければいけないので、それをチェックして最初のmov命令を出力する
    printf("  mov x0, %d\n", expect_number());

    // "+ <数>"" あるいは "- <数>" というトークンの並びを消費しつつアセンブリを出力する
    while (!at_eof()) {
        if (consume('+')) {
            printf("  add x0, x0, %d\n", expect_number());
            continue;
        }

        expect('-');
        printf("  sub x0, x0, %d\n", expect_number());
    }

    printf("  ret\n");
    return 0;
}
```

</details>

上のコードで使われているテクニック
* パーサが読み込むトークン列は、グローバル変数 `token` で表現している。パーサは、連結リストになっている `token` をたどっていくことで入力を読み進めていく。
  * グローバル変数を使うのは、あまりきれいなスタイルには見えないかもしれない。実際には、ここで行なっているように、入力トークン列を標準出力のようなストリームとして扱う方がパーサのコードが読みやすくなることが多い。
* `token` を直接触るコードは `consume` や `expect` といった関数に分けて、それ以外の関数では直接触らないようにした。
* `tokenize` 関数では、連結リストを構築している。連結リストを構築するときは、ダミーの `head` 要素を作ってそこに新しい要素をつなげていって、最後に `head->next` を返すようにするとコードが簡単になる。
  * このような方法では、`head` に割り当てられたメモリはほとんど無駄になるが、ローカル変数をアロケートするコストはほぼゼロなので、特に気にする必要はない。
* `callaloc` は `malloc` と同じようにメモリを割り当てる関数。`malloc` とは異なり、`calloc` は割り当てられたメモリをゼロクリアする。

`test.sh` に新しいケース `assert 41 " 12 + 34 - 5"` を追加する。


## ステップ4: エラーメッセージを改良


## 文法の記述方法と再帰下降構文解析


## スタックマシン


## ステップ5: 四則演算のできる言語の作成


## ステップ6: 単項プラスと単項マイナス


## ステップ7: 比較演算子

