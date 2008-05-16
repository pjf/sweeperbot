use inc::Module::Install;

name     'App-SweeperBot';
all_from 'lib/App/SweeperBot.pm';
author   'Paul Fenwick <pjf@cpan.org>';

build_requires 'Test::More';

auto_install;

WriteAll;

