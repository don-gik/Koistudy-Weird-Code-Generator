#!/bin/bash


# -------- Credits --------
# Project : Koistudy-Code-Generator
# Author  : don-gik@github.com





# ---- Global settings ----

SCRIPT_ARGS=("$@")

PROJECT="Koistudy-Code-Generator"
AUTHOR="don-gik@github.com"

LANG_ID=54                  # C++17
TIME_MS=1000
MEM_MB=128
API="https://koistudy.net/engine/api/koi_judge_case.php"


RUN_TIMEOUT=10
AUTO_YES=false
KEEP_ON_SUCCESS=false


PROGRAM_FINISHED="false"




# ---- Utils ----
function _new_section {
    echo ""
    echo ""
    echo "---------------- $1 ----------------"
    echo ""
}

function _output {
    if [[ $# -lt 2 ]]; then
        echo "[ Output ] : 2 positional arguments expected..."
        exit 1;
    fi

    echo "[ $1 ] : $2"
}

function _confirm {
    # _confirm "Prompt text" <default:Y|N>

    local prompt="$1"; local def="${2:-N}"

    # Check auto yes
    if $AUTO_YES; then
        [[ "$def" =~ ^[Yy]$ ]] && return 0 || return 1
    fi


    read -r -p "$prompt " ans


    ans=${ans%%[[:space:]]*}; ans=${ans,,}

    if [[ -z "$ans" ]]; then 
        ans="$def"
    fi
    
    [[ "$ans" == "y" || "$ans" == "yes" ]]
}

function _run_trap {
    local exit_code="$1"
    local gen_dir="$2"

    _new_section "Cleaning up"

    # gen_dir cleanup by exit code
    if [[ -n "$gen_dir" && -e "$gen_dir" && "$exit_code" -ne 0 ]]; then
        _output Clean "Removing generated scripts..."
        rm -rf -- "$gen_dir"
    fi

    _output Clean "Removing temporary files..."
    rm -rf -- tmp

    _output Clean "Cleaned up successfully."
}




set -Eeuo pipefail
TMPDIR="$(mktemp -d)"; trap 'ec=$?; _run_trap "$ec" "$TMPDIR";' EXIT






# ---- Initial Checks for Dependecy ----

_new_section "Initial Checks"

if [ -n "$BASH_VERSION" ]; then
    _output Check "Bash checked. Proceeding."
else
    _output Check "Please run the script with bash. Exiting program..."
    exit 1;
fi

for bin in jq curl g++; do
    command -v "$bin" >/dev/null || { _output Check "$bin required"; exit 3; }
done





# ---- Get Options ----

while (( "$#" )); do
    case "$1" in
        -o|--original) original="$2"; shift 2;;
        -g|--gen)      gen_path="$2"; shift 2;;
        -t|--target)   target="$2"; shift 2;;
        --timeout)     RUN_TIMEOUT="$2"; shift 2;;
        -y|--yes)      AUTO_YES=true; shift;;
        --keep)        KEEP_ON_SUCCESS=true; shift;;
        *) break;;
    esac
done





# ---- Previous logs and output files delete ----
if [[ -e logs || -e inputs || -e outputs ]]; then
    if _confirm "[ Check ] : Delete previous inputs, logs and outputs ? [y/N] :" N; then
        _output Check "Deleting user checked files from program..."
        rm -rf -- inputs logs outputs
    fi
fi



# ---- Check if the call is valid ----

# Validate required flags
if [[ -z ${original:-} || -z ${gen_path:-} || -z ${target:-} ]]; then
    if $AUTO_YES; then
        _output Check "Missing -o/--original, -g/--gen, or -t/--target"; exit 2
    fi
    read -r -p "[ Check ] : Input again. The original code : " original
    read -r -p "[ Check ] : Generated code path : " gen_path
    read -r -p "[ Check ] : The target problem number : " target
fi

_output Check "Original file name : $original"
_output Check "Generating file name : $gen_path"
_output Check "Target problem number : $target"

if [[ -e "$original" ]]; then
    _output Check "Code file $original exists. Continuing."
else
    _output Check "Code file doesn't exist. Exiting..."
    exit 2;
fi




# ---- Compile the code ----

_new_section Compiling


_output Compile "Compiling $original"

mkdir -p tmp
g++ -O2 -pipe -s -o tmp/original "$original" 2>tmp/compile.err || {
    _output Compile "compile failed:"
    cat tmp/compile.err
    exit 5
}


_output Compile "$original Compiled"






# ---- Check target availability ----

_new_section "Internet Check"

host="https://koistudy.net/prob_page?NO=$target"

_output Internet "Checking $host ..."
status=$(curl -fsS -o /dev/null -w "%{http_code}" "$host" || echo 000)

if [[ "${status:-0}" -eq 200 ]]; then
    _output Internet "Curl to $host successful. Continuing the process..."
else
    _output Internet "Curl to $host not successful. Status code : $status"
    _output Internet "Check if the problem number $target exists or not."

    exit 1;
fi






# ---- Generate the code by cat ----

_new_section "Initial Generation"


_output Generation "touch $gen_path"
mkdir -p "$(dirname "$gen_path")"
touch "$gen_path"

lang=cpp
cat > "$gen_path" << EOF
// -------- Credits --------
// Project : ${PROJECT}
// Author  : ${AUTHOR}

EOF

_output Generation "Basic testcase fetching code written."







# ---- Generate the output and input testcases txt ----

_new_section "Generate input testcases"


function json_escape {
    jq -Rs . < "$1";
}



# 1. Read total cases
cat > tmp/probe.cpp << 'CPP'
int main() {
    return 0;
}
CPP

src_escaped=$(json_escape tmp/probe.cpp)
response=$(
    curl -s -X POST "$API" \
        -H "Content-Type: application/json" \
        -d "{ \"prob_id\" : $target, \"lang_id\" : $LANG_ID, \"source\" : $src_escaped, \"case_no\" : 1, \"time_limit_ms\" : $TIME_MS, \"memory_limit_mb\" : $MEM_MB }"
)

total_cases=$(jq -r '.total_cases // 0' <<<"$response")


if [[ "$total_cases" -le 0 ]]; then
    _output Gen-Input "Failed to find total cases from api."
    _output Gen-Input "The response was : $response"
    _output Gen-Input "Exiting..."

    exit 6
else
    _output Gen-Input "Fetched the total cases : $total_cases"
fi



# 2. Make sniffer.cpp to sniff all the testcases
_output Gen-Input "Making cpp for sniffing..."

cat > tmp/sniffer.cpp << CPP
// -------- Credits --------
// Project : ${PROJECT}
// Author  : ${AUTHOR}


#include <bits/stdc++.h>


using namespace std;


int main() {
    ios_base::sync_with_stdio(false);
    cin.tie(nullptr);

    vector<string> a;
    
    for(string x; cin >> x;) a.push_back(x);
    for(auto x : a) cerr << x << " ";

    abort();
}

CPP

sniff_cpp_escaped=$(json_escape tmp/sniffer.cpp)



# Util function for extracting stderr flushes
function _extract_output {
    perl -0777 -ne 'if(/^(.*?)(?=\brun\b)/si){print $1}else{print $_}'
}

function _decode_ctrl {
    perl -0777 -pe 's/\\r\\n/\n/g; s/\\n/\n/g; s/\\t/\t/g'
}



# 3. Sniff all the testcases and save.
mkdir -p inputs outputs logs

for (( i=1; i<=total_cases; i++ )); do
    _output Gen-Input "case $i / $total_cases"

    # Get response and log it
    response=$(
        curl -s -X POST "$API" \
            -H "Content-Type: application/json" \
            -d "{\"prob_id\":$target,\"lang_id\":$LANG_ID,\"source\":$sniff_cpp_escaped,\"case_no\":$i,\"time_limit_ms\":$TIME_MS,\"memory_limit_mb\":$MEM_MB}"
    )

    echo "$response" > "logs/api_case_$i.json"


    status_desc=$(jq -r '.status_desc // "UNKNOWN"' <<< "$response")
    runtime_out=$(jq -r '.runtime_output // empty' <<< "$response")
    compile_out=$(jq -r '.compile_output // empty' <<< "$response")


    printf '%s' "$runtime_out" \
        | base64 -d \
        | _extract_output \
        | _decode_ctrl \
        > "inputs/case_$(printf '%02d' "$i").txt"
done






# ---- Generate output ----
_new_section "Generation Output"

for f in inputs/case_*.txt; do
    base=$(basename "$f" .txt)

    _output Gen-Output "Generating output from $base"

    if [[ -s "$f" ]]; then
        timeout "${RUN_TIMEOUT}s" ./tmp/original < "$f" > "outputs/${base}.txt"  2> "logs/${base}_stderr.txt" || true
    else 
        : > "outputs/${base}.txt"
    fi
done






# ---- Generate probe code ----
_new_section "Generate Code"

out_cpp="tmp/probe.cpp"

cat > tmp/probe.cpp << CPP
// -------- Credits --------
// Project : ${PROJECT}
// Author  : ${AUTHOR}

#include <bits/stdc++.h>


using namespace std;


static string normalize(string s) {
    
    for(char& c: s) if(c=='\r' || c=='\n' || c=='\t') c=' ';
    
    string t; t.reserve(s.size());
    bool in_sp=false;
    for(char c: s){
        if(c==' '){
            if(!in_sp){ t.push_back(' '); in_sp=true; }
        }else{
            t.push_back(c); in_sp=false;
        }
    }
    
    while(!t.empty() && t.back()==' ') t.pop_back();
    size_t i=0; while(i<t.size() && t[i]==' ') i++;
    return t.substr(i);
}


int main() {
    ios_base::sync_with_stdio(false);
    cin.tie(nullptr);

    string in((istreambuf_iterator<char>(cin)), istreambuf_iterator<char>());
    string x = normalize(in);
    
CPP


function _raw_rs {
    local f="$1"
    [[ -f "$f" ]] || { printf '/* missing: %s */ ""' "$f"; return; }

    if grep -q -F ')__KOI__"' "$f"; then
        # fallback: (escape + \n)
        printf '"'
        tr -d '\r' < "$f" \
        | perl -0777 -pe 's/[ \t]+$//mg; s/\s+\z//; s/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g'
        printf '"'
    else
        # raw string
        printf 'R"__KOI__('
        tr -d '\r' < "$f" \
        | perl -0777 -pe 's/[ \t]+$//mg; s/\s+\z//'
        printf ')__KOI__"'
    fi
}



mapfile -t CASES < <(printf '%s\n' inputs/case_*.txt | sort)

[[ ${#CASES[@]} -gt 0 ]] || { _output Generation "no inputs/case_*.txt"; exit 1; }


for in_f in "${CASES[@]}"; do
    base="${in_f##*/}"            # case_XX.txt
    out_f="outputs/$base"

    _output Generate "pair: $in_f"

    [[ -f "$out_f" ]] || { _output Generation "missing output for $base"; exit 1; }

    {
        printf '    // pair: %s <-> %s\n' "$in_f" "$out_f"
        printf '    if (x == '
        _raw_rs "$in_f"
        printf ') { cout << '
        _raw_rs "$out_f"
        printf '; return 0; }\n\n'
    } >> "$out_cpp"
done


cat >> "$out_cpp" <<'CPP'
    return 0;
}
CPP



_output Generate "Copying the tmp/probe to target..."
cp "$out_cpp" "$gen_path"






# ---- Finish and Cleanup ----

_new_section Finish

if $KEEP_ON_SUCCESS; then
    _output Finish "Keeping inputs, logs and outputs ( --keep )."
else
    if _confirm "[ Finish ] : Delete inputs, logs and outputs ? [y/N] :" N; then
        _output Finish "Deleting user checked files from program..."
        rm -rf -- inputs logs outputs
    fi
fi

_output Finish "Finished the program. Cleaning up..."



PROGRAM_FINISHED="true"
