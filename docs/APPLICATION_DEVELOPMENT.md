# Tresvita Application Development Guide

**Managed by Wissen Team**

This guide covers setting up the frontend (React) and backend (Java) application repositories for Tresvita with proper CI/CD integration.

## 📁 Repository Structure

### Tresvita Todo Frontend (React)
```
todo-frontend-eks/
├── public/
│   └── index.html
├── src/
│   ├── components/
│   │   └── TodoList.js
│   ├── services/
│   │   └── api.js
│   ├── App.js
│   ├── App.css
│   ├── index.js
│   └── index.css
├── Dockerfile
├── nginx.conf
├── package.json
└── README.md
```

### Tresvita Todo Backend (Java Spring Boot)
```
todo-backend-eks/
├── src/
│   └── main/
│       ├── java/com/tresvita/todo/
│       │   ├── TodoApplication.java
│       │   ├── controller/
│       │   │   └── TodoController.java
│       │   ├── service/
│       │   │   ├── TodoService.java
│       │   │   └── TodoNotFoundException.java
│       │   ├── repository/
│       │   │   └── TodoRepository.java
│       │   └── model/
│       │       └── Todo.java
│       └── resources/
│           └── application.yml
├── Dockerfile
├── pom.xml
└── README.md
```

## 🎨 Frontend Repository Setup (React)

### 1. Initialize Repository

```bash
# Create directory
mkdir todo-frontend
cd todo-frontend

# Initialize git
git init

# Create React app
npx create-react-app . --template typescript

# Or without TypeScript
npx create-react-app .
```

### 2. Project Structure

```bash
# Create directory structure
mkdir -p src/components src/pages src/services src/utils src/hooks

# Create sample files
touch src/components/TodoList.js
touch src/components/TodoItem.js
touch src/pages/Home.js
touch src/services/api.js
```

### 3. API Service

Create `src/services/api.js`:

```javascript
const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:8080/api';

export const fetchTodos = async () => {
  const response = await fetch(`${API_URL}/todos`);
  if (!response.ok) throw new Error('Failed to fetch todos');
  return response.json();
};

export const createTodo = async (todo) => {
  const response = await fetch(`${API_URL}/todos`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(todo),
  });
  if (!response.ok) throw new Error('Failed to create todo');
  return response.json();
};

export const updateTodo = async (id, todo) => {
  const response = await fetch(`${API_URL}/todos/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(todo),
  });
  if (!response.ok) throw new Error('Failed to update todo');
  return response.json();
};

export const deleteTodo = async (id) => {
  const response = await fetch(`${API_URL}/todos/${id}`, {
    method: 'DELETE',
  });
  if (!response.ok) throw new Error('Failed to delete todo');
};
```

### 4. Todo Components

Create `src/components/TodoList.js`:

```javascript
import React, { useState, useEffect } from 'react';
import { fetchTodos, createTodo, updateTodo, deleteTodo } from '../services/api';

const TodoList = () => {
  const [todos, setTodos] = useState([]);
  const [newTodo, setNewTodo] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadTodos();
  }, []);

  const loadTodos = async () => {
    try {
      setLoading(true);
      const data = await fetchTodos();
      setTodos(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleAddTodo = async (e) => {
    e.preventDefault();
    if (!newTodo.trim()) return;
    
    try {
      const todo = await createTodo({ title: newTodo, completed: false });
      setTodos([...todos, todo]);
      setNewTodo('');
    } catch (err) {
      setError(err.message);
    }
  };

  const handleToggleTodo = async (id) => {
    const todo = todos.find(t => t.id === id);
    try {
      const updated = await updateTodo(id, { ...todo, completed: !todo.completed });
      setTodos(todos.map(t => t.id === id ? updated : t));
    } catch (err) {
      setError(err.message);
    }
  };

  const handleDeleteTodo = async (id) => {
    try {
      await deleteTodo(id);
      setTodos(todos.filter(t => t.id !== id));
    } catch (err) {
      setError(err.message);
    }
  };

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error}</div>;

  return (
    <div className="todo-app">
      <h1>Todo Application</h1>
      
      <form onSubmit={handleAddTodo}>
        <input
          type="text"
          value={newTodo}
          onChange={(e) => setNewTodo(e.target.value)}
          placeholder="Add a new todo..."
        />
        <button type="submit">Add</button>
      </form>

      <ul className="todo-list">
        {todos.map(todo => (
          <li key={todo.id} className={todo.completed ? 'completed' : ''}>
            <input
              type="checkbox"
              checked={todo.completed}
              onChange={() => handleToggleTodo(todo.id)}
            />
            <span>{todo.title}</span>
            <button onClick={() => handleDeleteTodo(todo.id)}>Delete</button>
          </li>
        ))}
      </ul>
    </div>
  );
};

export default TodoList;
```

### 5. Update App.js

```javascript
import React from 'react';
import TodoList from './components/TodoList';
import './App.css';

function App() {
  return (
    <div className="App">
      <TodoList />
    </div>
  );
}

export default App;
```

### 6. Add Basic Styles

Update `src/App.css`:

```css
.App {
  max-width: 600px;
  margin: 0 auto;
  padding: 20px;
  font-family: Arial, sans-serif;
}

.todo-app h1 {
  text-align: center;
  color: #333;
}

form {
  display: flex;
  margin-bottom: 20px;
}

form input {
  flex: 1;
  padding: 10px;
  font-size: 16px;
  border: 1px solid #ddd;
  border-radius: 4px;
}

form button {
  padding: 10px 20px;
  margin-left: 10px;
  background-color: #007bff;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

form button:hover {
  background-color: #0056b3;
}

.todo-list {
  list-style: none;
  padding: 0;
}

.todo-list li {
  display: flex;
  align-items: center;
  padding: 10px;
  border-bottom: 1px solid #eee;
}

.todo-list li.completed span {
  text-decoration: line-through;
  color: #888;
}

.todo-list li input[type="checkbox"] {
  margin-right: 10px;
}

.todo-list li span {
  flex: 1;
}

.todo-list li button {
  padding: 5px 10px;
  background-color: #dc3545;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

.todo-list li button:hover {
  background-color: #c82333;
}
```

### 7. Create Dockerfile

```dockerfile
# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built files
COPY --from=builder /app/build /usr/share/nginx/html

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
```

### 8. Create nginx.conf

```nginx
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript;

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Handle React Router
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
```

### 9. Create Jenkinsfile

See the Jenkins setup guide for the complete Jenkinsfile.

### 10. Commit and Push

```bash
git add .
git commit -m "Initial React application setup"
git remote add origin https://github.com/your-org/todo-frontend.git
git push -u origin main

# Create develop branch
git checkout -b develop
git push -u origin develop
```

## ☕ Backend Repository Setup (Java/Spring Boot)

### 1. Initialize Repository

```bash
mkdir todo-backend
cd todo-backend

# Create Spring Boot project
curl https://start.spring.io/starter.zip \
  -d dependencies=web,data-jpa,postgresql,actuator,lombok \
  -d type=maven-project \
  -d bootVersion=3.2.0 \
  -d baseDir=. \
  -o backend.zip

unzip backend.zip
rm backend.zip
```

### 2. Project Structure

```bash
mkdir -p src/main/java/com/todo/{controller,service,repository,model,config}
mkdir -p src/main/resources
mkdir -p src/test/java/com/todo
```

### 3. Create Todo Model

Create `src/main/java/com/todo/model/Todo.java`:

```java
package com.todo.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "todos")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Todo {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(nullable = false)
    private String title;
    
    @Column(length = 1000)
    private String description;
    
    @Column(nullable = false)
    private boolean completed = false;
    
    @Column(name = "created_at")
    private LocalDateTime createdAt;
    
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
    
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }
    
    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
```

### 4. Create Repository

Create `src/main/java/com/todo/repository/TodoRepository.java`:

```java
package com.todo.repository;

import com.todo.model.Todo;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface TodoRepository extends JpaRepository<Todo, Long> {
    List<Todo> findByCompleted(boolean completed);
    List<Todo> findByTitleContainingIgnoreCase(String title);
}
```

### 5. Create Service

Create `src/main/java/com/todo/service/TodoService.java`:

```java
package com.todo.service;

import com.todo.model.Todo;
import com.todo.repository.TodoRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional
public class TodoService {
    
    private final TodoRepository todoRepository;
    
    public List<Todo> findAll() {
        return todoRepository.findAll();
    }
    
    public Todo findById(Long id) {
        return todoRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Todo not found with id: " + id));
    }
    
    public Todo create(Todo todo) {
        return todoRepository.save(todo);
    }
    
    public Todo update(Long id, Todo todoDetails) {
        Todo todo = findById(id);
        todo.setTitle(todoDetails.getTitle());
        todo.setDescription(todoDetails.getDescription());
        todo.setCompleted(todoDetails.isCompleted());
        return todoRepository.save(todo);
    }
    
    public void delete(Long id) {
        Todo todo = findById(id);
        todoRepository.delete(todo);
    }
    
    public List<Todo> findByCompleted(boolean completed) {
        return todoRepository.findByCompleted(completed);
    }
}
```

### 6. Create Controller

Create `src/main/java/com/todo/controller/TodoController.java`:

```java
package com.todo.controller;

import com.todo.model.Todo;
import com.todo.service.TodoService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/todos")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class TodoController {
    
    private final TodoService todoService;
    
    @GetMapping
    public ResponseEntity<List<Todo>> getAllTodos() {
        return ResponseEntity.ok(todoService.findAll());
    }
    
    @GetMapping("/{id}")
    public ResponseEntity<Todo> getTodoById(@PathVariable Long id) {
        return ResponseEntity.ok(todoService.findById(id));
    }
    
    @PostMapping
    public ResponseEntity<Todo> createTodo(@RequestBody Todo todo) {
        return ResponseEntity.status(HttpStatus.CREATED).body(todoService.create(todo));
    }
    
    @PutMapping("/{id}")
    public ResponseEntity<Todo> updateTodo(@PathVariable Long id, @RequestBody Todo todo) {
        return ResponseEntity.ok(todoService.update(id, todo));
    }
    
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteTodo(@PathVariable Long id) {
        todoService.delete(id);
        return ResponseEntity.noContent().build();
    }
    
    @GetMapping("/completed/{completed}")
    public ResponseEntity<List<Todo>> getTodosByCompleted(@PathVariable boolean completed) {
        return ResponseEntity.ok(todoService.findByCompleted(completed));
    }
}
```

### 7. Update Application Properties

Update `src/main/resources/application.yml`:

```yaml
server:
  port: 8080
  servlet:
    context-path: /api

spring:
  application:
    name: todo-backend
  
  datasource:
    url: jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME:todo_db}
    username: ${DB_USER:postgres}
    password: ${DB_PASSWORD:password}
    driver-class-name: org.postgresql.Driver
  
  jpa:
    hibernate:
      ddl-auto: update
    show-sql: true
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
        format_sql: true

management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics
  endpoint:
    health:
      show-details: always
      probes:
        enabled: true
  health:
    livenessstate:
      enabled: true
    readinessstate:
      enabled: true

logging:
  level:
    com.todo: DEBUG
    org.springframework.web: INFO
  pattern:
    console: "%d{yyyy-MM-dd HH:mm:ss} - %msg%n"
```

### 8. Create Dockerfile

```dockerfile
# Build stage
FROM maven:3.9-eclipse-temurin-17-alpine AS builder

WORKDIR /app

# Copy pom.xml and download dependencies
COPY pom.xml .
RUN mvn dependency:go-offline

# Copy source code
COPY src ./src

# Build application
RUN mvn clean package -DskipTests

# Production stage
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy built jar
COPY --from=builder /app/target/*.jar app.jar

# Change ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/api/actuator/health || exit 1

# Run application
ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", "-jar", "app.jar"]
```

### 9. Create Jenkinsfile

See the Jenkins setup guide for the complete Jenkinsfile.

### 10. Commit and Push

```bash
git init
git add .
git commit -m "Initial Spring Boot application setup"
git remote add origin https://github.com/your-org/todo-backend.git
git push -u origin main

git checkout -b develop
git push -u origin develop
```

## 🔄 Git Branching Strategy

### Branch Structure

```
main (production)
  ↑
staging (staging environment)
  ↑
develop (integration branch)
  ↑
feature/* (feature branches)
```

### Workflow

1. **Feature Development**:
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/add-search
   # Make changes
   git commit -m "Add search functionality"
   git push origin feature/add-search
   # Create PR to develop
   ```

2. **Deploy to Dev**:
   - Merge PR to `develop`
   - Jenkins automatically deploys to dev environment

3. **Deploy to Staging**:
   ```bash
   git checkout staging
   git merge develop
   git push origin staging
   # Jenkins deploys to staging
   ```

4. **Deploy to Production**:
   ```bash
   git checkout main
   git merge staging
   git push origin main
   # Manual approval in Jenkins
   # Deploys to production
   ```

## 🧪 Testing Strategy

### Frontend Testing

```bash
# Unit tests
npm test

# Coverage
npm test -- --coverage

# E2E tests (Cypress)
npx cypress open
```

### Backend Testing

```bash
# Unit tests
./mvnw test

# Integration tests
./mvnw verify

# Coverage
./mvnw jacoco:report
```

## 📦 Versioning

Use semantic versioning:
- MAJOR.MINOR.PATCH
- Example: 1.2.3

Tag releases:
```bash
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

---

**Next:** [Operations Guide](OPERATIONS.md)
