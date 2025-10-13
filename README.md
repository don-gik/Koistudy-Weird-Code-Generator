# Koistudy Weird Code Generator



### Credits
Fully scripted by don-gik@github.com

Project : Koistudy Code Generator


### Requirements
- Bash >= 4.0
  - jq
  - curl
  - g++
- Internet connection


### How to use
This program can be used by :

```
./generate.sh -o [original file] \
              -g [generated path] \
              -t [target problem number] 
```

or

```
./generate.sh
```

If used like this, the script will run other variables with default values.

Additional options are provided :
```
./generate.sh -o [original file] \
              -g [generated path] \
              -t [target problem number] \
              --timeout [timeout for each testcases running code] \
              -y [automatical yes] \
              --keep [keep artifacts]
```

The program only supports c++ yet.


### Options
* ##### Original File
  * The original file means the correct code for the problem to solve.
  * You *MUST* set it to run the script.
* ##### Generated Path
  * New code giving same outputs only for the testcases will be automatically generated.
  * This options sets up where to make the file. You can set it up to something like "code.cpp"
  * You *MUST* set it to run the script.
* ##### Target Problem Number
  * To fetch the testcases, target problem number is required.
  * Fetching from the contests are not supported; may be added in future release.
  * You *MUST* set it to run the script.
* ##### Timeout
  * Timeout variable controls the time limit for generating output pair for input testcase pairs.
  * This variable limits amount of time for running a correct code for each testcase.
  * The default value for this is 10.
* ##### Automatical Yes
  * Set this up for other scripts, and non-conversational circumstances. Replies yes for each question.
  * It works similar to noconfirm.
* ##### Keep
  * The program generates input, ouput, and logs folder as artifact where the script file exists. Keep option makes this program to keep its artifact after finished without confirming.

There are three required options : -o, -g, -t. If you don't know how to use them, or prefer using UI, then use UI input system. The program will ask for the values before doing any process.




### Future Notes
* Maybe POSIX supports and other os supports?
* Flexible implementation?