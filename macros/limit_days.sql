{%- macro limit_days(date_column, table, days = 3) -%}

    {%- if target.name == 'default' -%}

        WHERE {{ date_column }} >=  
            (SELECT DATE_SUB (MAX({{ date_column }}), INTERVAL {{ days }} DAY)
            FROM {{ ref(table) }} )

    {%- endif -%}

{% endmacro %}