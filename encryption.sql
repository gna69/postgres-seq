
--шифрование столбца
create or replace function encrypt_client()
returns trigger as $$
begin
      update Schedule set (Client) = (pgp_sym_encrypt(new.client::text, 'sashakias')) where id = new.id;
      return new;
end;
$$ language plpgsql;
drop function encrypt_client();

-- шифрование таблицы
create or replace function encrypt_client()
returns trigger as $$
begin
      update Schedule set (master, client, box, car, cost, work) = ((pgp_sym_encrypt(new.Master, 'sashakias')),
                                                                   (pgp_sym_encrypt(new.Client, 'sashakias')),
                                                                   (pgp_sym_encrypt(new.Box::text, 'sashakias')),
                                                                   (pgp_sym_encrypt(new.Car, 'sashakias')),
                                                                   (pgp_sym_encrypt(new.Cost::text, 'sashakias')),
                                                                   (pgp_sym_encrypt(new.Work, 'sashakias'))) where id = new.id;
      return new;
end;
$$ language plpgsql;
drop function encrypt_client();
