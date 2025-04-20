{%- macro limit_days(date_column, table, days = 3) -%}

    {{ log('This is your current target name: '~ target.name, info = True ) }}

    {%- if target.name == 'default' -%}

        WHERE {{ date_column }} >=  
            (SELECT DATE_SUB (MAX({{ date_column }}), INTERVAL {{ days }} DAY)
            FROM {{ ref(table) }} )

    {%- endif -%}

{% endmacro %}