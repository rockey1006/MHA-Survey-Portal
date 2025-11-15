# Development Guide

## Project Structure

- `app/controllers/` – Controllers
- `app/models/` – Models
- `app/views/` – Views
- `app/services/` – Service objects
- `db/` – Database schema and seeds
- `config/` – Configuration files
- `test/` – Test suite

## Code Style & Conventions

- Follows [Ruby Style Guide](https://rubystyle.guide/)
- Lint with RuboCop: `docker-compose exec web bundle exec rubocop`
- Auto-correct style issues: `docker-compose exec web bundle exec rubocop -a`
- Consider using a linter extension in your code editor (e.g., VS Code Ruby Linter) for real-time feedback.
- Use descriptive commit messages

## Testing

- Run all tests: `docker-compose exec web rails test`
- System tests: `test/system/`
- How to write and run new tests

## Deployment

- Local: Docker Compose
- Production: Build Docker image, push to registry, deploy to cloud (Heroku, AWS, etc.)
- Environment variables and secrets management

## Debugging

- Using Rails console: `docker-compose exec web rails console`
- Viewing logs: `docker-compose logs web`
- Common errors and solutions
