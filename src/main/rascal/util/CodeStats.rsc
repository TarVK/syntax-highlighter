module util::CodeStats

import util::FileSystem;
import analysis::grammars::LOC;
import Visualize;

void main() {
    stats = slocStats(crawl(|project://syntax-highlighter/src/main/rascal|), <0, ()>);
    visualize(stats);
}