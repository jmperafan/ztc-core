{% snapshot snap_club_members %}

{{
    config(
        target_schema='snapshots',
        unique_key='member_id',
        strategy='check',
        check_cols=[
            'current_type_of_membership',
            'is_club_member',
            'city',
            'reasons_for_cancellation',
            'singles_level',
            'doubles_level'
        ]
    )
}}

SELECT * FROM {{ ref('stg_club_members') }}

{% endsnapshot %}
