# 電卓レベルの言語の作成
* この章の目標は、Cコンパイラ作成の最初のステップとして `30 + (4 - 2) * 5` のような式をコンパイルできるようにすること。
* 数式には、カッコの中の式が優先される・掛け算が足し算より優先される、などの構造があって、それを何らかの方法で理解しなければ正しく計算できない。
* 入力として与えられる数式はフラットな文字の列で、構造化されたデータではない。式を正しく評価するには、文字の並びを解析して、そこに隠れた構造をうまく導き出す必要がある。
* 構文解析の最も一般的なアルゴリズムである **再帰下降構文** を使う。

## ステップ1: 整数1個をコンパイルする言語の作成
ここでは、1個の整数を入力から読んで、その数をプログラムの終了コードとして終了するアセンブリを出力するコンパイラを作る。`hcc` という名前のコンパイラを作っていく（`gcc` が主流なのでgの次のh、という意味とhashimotoのhという2つの意味を込めた）。

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


## ステップ3: トークナイザを導入


## ステップ4: エラーメッセージを改良


## 文法の記述方法と再帰下降構文解析


## スタックマシン


## ステップ5: 四則演算のできる言語の作成


## ステップ6: 単項プラスと単項マイナス


## ステップ7: 比較演算子
