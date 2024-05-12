import re

# Prompt:
# Give me a script that generates a handlebars template of from an input file with the following changes. This script should do case sensitive searches when finding and replacing. It does not need to search for whole words:
# 1. Change coin_example to {{name_snake_case}}
# 2. Change `COIN_EXAMPLE` to `{{name_snake_case_caps}}`
# 3. Find this line: let (treasury_cap, coin_metadata) = coin::create_currency<COIN_EXAMPLE>(witness, 9, b"COIN_EXAMPLE", b"XMP", b"", option::none(), ctx);, replace with `let (treasury_cap, metadata) = coin::create_currency<{{name_snake_case_caps}}>(witness, {{decimals}}, b"{{name_snake_case_caps}}", b"{{symbol}}", b"{{description}}", b"{{icon_url}}", ctx);
#     1. Note that if this was done in order COIN_EXAMPLE might be {{name_snake_case_caps}} here, code should account for that
#     2. Instead of doing this line exactly, search for a line like it, except for "COIN_EXAMPLE" and "XMP" which should be hardcoded. So your search should find (treasury_cap, coin_metadata) = coin::create_currency<COIN_EXAMPLE>(witness, 2, b"COIN_EXAMPLE", b"XMP", b"someothervaluehere", option::none(), ctx); but should not find let (treasury_cap, coin_metadata) = coin::create_currency<COINS_EXAMPLE>(witness, 9, b"SSSSSOIN_EXAMPLE", b"XXMP", b"", b"", ctx);
# 4. Search for CoinExample replace with {{name_capital_camel_case}}
# 5. In all of the above, things in double brackets are strings you should use, not values. For example, the replace for COIN_EXAMPLE with {{name_snake_case_caps}} should replace a string, COIN_EXAMPLE, with a string {{name_snake_case_caps}}, not a value name_snake_case_caps

def process_file(input_file, output_file):
    with open(input_file, 'r') as file:
        content = file.read()

    # Change `coin_example` to `{{name_snake_case}}`
    content = content.replace('coin_example', '{{name_snake_case}}')

    # Change `COIN_EXAMPLE` to `{{name_snake_case_caps}}`
    content = content.replace('COIN_EXAMPLE', '{{name_snake_case_caps}}')

    # Find the line with `let (treasury_cap, coin_metadata) = coin::create_currency<COIN_EXAMPLE>(witness, 9, b"COIN_EXAMPLE", b"XMP", b"", option::none(), ctx);`
    pattern = re.compile(r'let \(treasury_cap, coin_metadata\) = coin::create_currency<COIN_EXAMPLE>\(witness, \d+, b"COIN_EXAMPLE", b"XMP", b".*?", .*?, ctx\);')
    match = pattern.search(content)
    if match:
        old_line = match.group()
        new_line = 'let (treasury_cap, metadata) = coin::create_currency<{{name_snake_case_caps}}>(witness, {{decimals}}, b"{{name_snake_case_caps}}", b"{{symbol}}", b"{{description}}", option::some(url::new_unsafe_from_bytes(b"{{icon_url}}")), ctx);'
        content = content.replace(old_line, new_line)

    # Search for `CoinExample` and replace with `{{name_capital_camel_case}}`
    content = content.replace('CoinExample', '{{name_capital_camel_case}}')

    with open(output_file, 'w') as file:
        file.write(content)

# Example usage
input_file = 'sources/coin_example.move'
output_file = 'coin_template.hs.move'

process_file(input_file, output_file)