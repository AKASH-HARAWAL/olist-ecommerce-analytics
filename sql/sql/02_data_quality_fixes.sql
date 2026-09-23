-- Data Quality Fix 1: Missing category mappings
-- 2 product categories existed in the products source data but were
-- missing from the official product_category_name_translation table.
-- Identified via LEFT JOIN against a staging table, then added manually:
INSERT INTO product_category_name_translation (product_category_name, product_category_name_english)
VALUES 
    ('pc_gamer', 'pc_gamer'),
    ('portateis_cozinha_e_preparadores_de_alimentos', 'portable_kitchen_food_preparators');

-- Data Quality Fix 2: Character encoding mismatch in order_reviews
-- The review_comment_message field contained WIN1252-encoded characters
-- incompatible with the default UTF8 client encoding, causing COPY to fail
-- at line 340. Resolved by explicitly setting the client encoding before
-- running the import:
-- SET client_encoding = 'UTF8';