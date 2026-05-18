# MoonBit project commands

target := "js"

default: check test

fmt:
    moon fmt

check:
    moon check --deny-warn --target {{target}}

test:
    moon test --target {{target}}

test-update:
    moon test --update --target {{target}}

info:
    moon info

clean:
    moon clean

release-check: fmt info check test
