import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ui, UiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "Hvw+YJdM26sY6nzf9/3SySLGAkSuY/3e0uf/MF3m9wVIjaVe2dGWQt6+OAM4wJzg",
  server: false

# In test we don't send emails.
config :ui, Ui.Mailer,
  adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
