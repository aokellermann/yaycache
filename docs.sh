#!/bin/bash

(cd doc && make html website)

rm docs/*.html docs/*.css docs/*.js
tar -xvzf doc/website.tar.gz -C docs
mv docs/yaycache.8.html docs/index.html
