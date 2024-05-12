import re

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
        new_line = 'let (treasury_cap, metadata) = coin::create_currency<{{name_snake_case_caps}}>(witness, {{decimals}}, b"{{name_snake_case_caps}}", b"{{symbol}}", b"{{description}}", {{icon_url}}, ctx);'
        content = content.replace(old_line, new_line)

    # Search for `CoinExample` and replace with `{{name_capital_camel_case}}`
    content = content.replace('CoinExample', '{{name_capital_camel_case}}')

    with open(output_file, 'w') as file:
        file.write(content)

# Example usage
input_file = 'sources/coin_example.move'
output_file = 'coin_template.hs.move'

process_file(input_file, output_file)