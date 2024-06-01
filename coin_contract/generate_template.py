import re


# This function replaces anchors in our reference coin contract, coin_example.move, with handlebars anchors
# The backend will populate the handlebars anchors with values provided to it from the createCoin form in the frontend
def process_file(input_file, output_file):
    with open(input_file, 'r') as file:
        content = file.read()

    # Module name, otw, and path anchors
    content = content.replace('coin_contract', '{{name_snake_case}}')
    content = content.replace('COIN_CONTRACT', '{{name_snake_case_caps}}')
    content = content.replace('CoinContract', '{{name_capital_camel_case}}')

    # CoinMetadata anchors
    content = content.replace('COIN_METADATA_NAME', '{{name_snake_case_caps}}')
    content = content.replace('COIN_METADATA_ICON_URL', '{{coin_metadata_icon_url}}')
    content = content.replace('COIN_METADATA_SYMBOL', '{{coin_metadata_symbol}}')
    content = content.replace('COIN_METADATA_DESCRIPTION', '{{coin_metadata_description}}')

    # Metadata anchors we added for a better frontend experience
    content = content.replace('OPTIONAL_METADATA_WEBSITE_URL', '{{optional_metadata_website_url}}')
    content = content.replace('OPTIONAL_METADATA_TELEGRAM_URL', '{{optional_metadata_telegram_url}}')
    content = content.replace('OPTIONAL_METADATA_DISCORD_URL', '{{optional_metadata_discord_url}}')
    content = content.replace('OPTIONAL_METADATA_TWITTER_URL', '{{optional_metadata_twitter_url}}')

    # TODO below doesn't work, fix laster
    content = re.sub(r'(?s)// BEGIN_TEST.*?//END_TEST', '', content)

    with open(output_file, 'w') as file:
        file.write(content)

# Example usage
input_file = 'sources/coin_contract.move'
output_file = 'coin_template.hs.move'

process_file(input_file, output_file)