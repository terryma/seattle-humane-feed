CREATE TABLE cats (
    id int PRIMARY KEY,
    name varchar(80) NOT NULL,
    first_available timestamp with time zone NOT NULL,
    last_available timestamp with time zone NOT NULL
);
