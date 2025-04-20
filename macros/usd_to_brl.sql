{% macro usd_to_brl(column_name, decimal_places = 2) -%}

    round ({{ column_name }} * 5.6, {{ decimal_places }})

{%- endmacro %}