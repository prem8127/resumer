/// Static course catalog for the learning module.
///
/// Read-only starter content available as an offline fallback and imported
/// into Supabase by an administrator during initial setup.
library;

import '../models/models.dart';

const List<Course> kCourseCatalog = [
  Course(
    id: 'py-masterclass',
    title: 'Python Masterclass',
    category: 'Programming',
    instructor: 'John Doe',
    level: 'Beginner',
    priceLabel: '₹199',
    rating: 4.8,
    studentsLabel: '1.2k students',
    description: 'A complete introduction to Python — syntax, data structures, '
        'functions, and enough real practice to start building.',
    lessons: [
      CourseLesson(
        id: 'py-1',
        title: 'What is Python?',
        durationLabel: '6 min',
        content: 'Python is a high-level, general-purpose language known for '
            'readable syntax and a huge ecosystem of libraries. It runs on '
            'nearly every platform and is used across web development, '
            'data science, automation, and AI/ML tooling.',
        keyPoints: [
          'Interpreted, dynamically typed language',
          'Readable, indentation-based syntax',
          'Huge standard library + package ecosystem (PyPI)',
        ],
      ),
      CourseLesson(
        id: 'py-2',
        title: 'Why Python?',
        durationLabel: '5 min',
        content:
            'Python trades a little raw speed for a lot of developer speed. '
            'It is often the first language taught because the syntax gets '
            'out of the way of the logic — and it scales up into serious '
            'production systems at companies like Google, Instagram, and '
            'Netflix.',
        keyPoints: [
          'Fast to write and read',
          'Strong for scripting, data, and backend APIs',
          'Massive job market demand',
        ],
      ),
      CourseLesson(
        id: 'py-3',
        title: 'Installing Python',
        durationLabel: '4 min',
        content: 'Install Python from python.org or via a package manager. '
            'Verify the install by running "python --version" in a '
            'terminal. Most editors (VS Code, PyCharm) detect the '
            'interpreter automatically once installed.',
        keyPoints: [
          'Download from python.org (3.x)',
          'Verify with: python --version',
          'Pick an editor: VS Code or PyCharm',
        ],
      ),
      CourseLesson(
        id: 'py-4',
        title: 'Variables & Data Types',
        durationLabel: '9 min',
        content: 'Variables in Python are created on assignment — no type '
            'keyword needed. Core built-in types are int, float, str, bool, '
            'list, tuple, dict, and set. Python infers the type from the '
            'value, and you can check it with type(x).',
        keyPoints: [
          'name = "value" — no declaration needed',
          'Core types: int, float, str, bool, list, dict',
          'type(x) tells you what you\'re working with',
        ],
      ),
      CourseLesson(
        id: 'py-5',
        title: 'Your First Program',
        durationLabel: '7 min',
        content:
            'Every Python journey starts with print("Hello, World!"). From '
            'there, try taking input with input(), doing basic math, and '
            'combining variables into an f-string. Small programs like '
            'this build the muscle memory for everything that follows.',
        keyPoints: [
          'print() writes to the console',
          'input() reads a line of text from the user',
          'f"{value}" formats variables into strings',
        ],
      ),
    ],
    finalTest: [
      CourseTestQuestion(
        question: 'Which of the following is a valid variable name in Python?',
        options: ['1name', 'name_1', '@name', 'name-1'],
        correctIndex: 1,
      ),
      CourseTestQuestion(
        question: 'Which function prints output to the console?',
        options: ['echo()', 'console.log()', 'print()', 'write()'],
        correctIndex: 2,
      ),
      CourseTestQuestion(
        question: 'What does input() return?',
        options: [
          'An integer',
          'A string',
          'A boolean',
          'Nothing, it only displays text',
        ],
        correctIndex: 1,
      ),
      CourseTestQuestion(
        question: 'Which of these is NOT a built-in Python type?',
        options: ['list', 'dict', 'struct', 'tuple'],
        correctIndex: 2,
      ),
    ],
  ),
  Course(
    id: 'react-dev',
    title: 'React Development',
    category: 'Web Development',
    instructor: 'John Doe',
    level: 'Intermediate',
    priceLabel: '₹199',
    rating: 4.6,
    studentsLabel: '890 students',
    description:
        'Build interactive UIs with React — components, props, state, and '
        'hooks — from first principles.',
    lessons: [
      CourseLesson(
        id: 'react-1',
        title: 'Components & JSX',
        durationLabel: '8 min',
        content:
            'React apps are built from components — small, reusable pieces '
            'of UI written as functions that return JSX. JSX looks like '
            'HTML but compiles down to JavaScript function calls.',
        keyPoints: [
          'A component is a function returning JSX',
          'JSX mixes markup and JavaScript expressions',
          'Components compose into a tree',
        ],
      ),
      CourseLesson(
        id: 'react-2',
        title: 'Props',
        durationLabel: '6 min',
        content: 'Props pass data from a parent component into a child. They '
            'are read-only from the child\'s perspective — a child never '
            'modifies its own props directly.',
        keyPoints: [
          'Props flow one-way: parent → child',
          'Props are read-only in the child',
          'Destructure props for readability',
        ],
      ),
      CourseLesson(
        id: 'react-3',
        title: 'State with useState',
        durationLabel: '10 min',
        content: 'State lets a component remember and update values across '
            'renders. useState returns the current value and a setter — '
            'calling the setter schedules a re-render with the new value.',
        keyPoints: [
          'const [value, setValue] = useState(initial)',
          'Calling the setter triggers a re-render',
          'Never mutate state directly',
        ],
      ),
      CourseLesson(
        id: 'react-4',
        title: 'Handling Events',
        durationLabel: '6 min',
        content: 'React events are named in camelCase (onClick, onChange) and '
            'take a function, not a string. Event handlers commonly update '
            'state to trigger a UI change.',
        keyPoints: [
          'onClick={handler}, not onClick="handler()"',
          'Handlers usually call a state setter',
          'Avoid inline arrow functions in hot loops',
        ],
      ),
    ],
    finalTest: [
      CourseTestQuestion(
        question: 'What does a React component return?',
        options: ['JSON', 'JSX', 'YAML', 'SQL'],
        correctIndex: 1,
      ),
      CourseTestQuestion(
        question: 'How does data flow between components using props?',
        options: [
          'Child to parent only',
          'Parent to child only',
          'Both directions freely',
          'Props cannot pass data',
        ],
        correctIndex: 1,
      ),
      CourseTestQuestion(
        question: 'What does calling a useState setter do?',
        options: [
          'Deletes the component',
          'Triggers a re-render with the new value',
          'Freezes the current render',
          'Nothing until the page reloads',
        ],
        correctIndex: 1,
      ),
    ],
  ),
  Course(
    id: 'sql-fundamentals',
    title: 'SQL Fundamentals',
    category: 'Data',
    instructor: 'Meera Nair',
    level: 'Beginner',
    priceLabel: 'Free',
    rating: 4.7,
    studentsLabel: '2.1k students',
    description: 'Query relational databases confidently — SELECT, filtering, '
        'joins, and aggregation.',
    isFree: true,
    lessons: [
      CourseLesson(
        id: 'sql-1',
        title: 'SELECT & WHERE',
        durationLabel: '7 min',
        content:
            'SELECT chooses columns, WHERE filters rows. Together they are '
            'the two clauses you\'ll write most often: '
            'SELECT name, email FROM users WHERE active = true.',
        keyPoints: [
          'SELECT columns FROM table',
          'WHERE filters which rows come back',
          'Combine conditions with AND / OR',
        ],
      ),
      CourseLesson(
        id: 'sql-2',
        title: 'JOINs',
        durationLabel: '9 min',
        content: 'JOINs combine rows across tables using a shared key. INNER '
            'JOIN keeps only matching rows; LEFT JOIN keeps every row from '
            'the left table even without a match.',
        keyPoints: [
          'INNER JOIN: only matching rows',
          'LEFT JOIN: keep all left-table rows',
          'Join on a shared key column',
        ],
      ),
      CourseLesson(
        id: 'sql-3',
        title: 'GROUP BY & Aggregates',
        durationLabel: '8 min',
        content:
            'COUNT, SUM, AVG, MIN, and MAX summarize data. GROUP BY buckets '
            'rows before aggregating — e.g. total orders per customer.',
        keyPoints: [
          'Aggregates: COUNT, SUM, AVG, MIN, MAX',
          'GROUP BY buckets rows before aggregating',
          'HAVING filters after aggregation',
        ],
      ),
    ],
    finalTest: [
      CourseTestQuestion(
        question: 'Which clause filters rows before aggregation?',
        options: ['HAVING', 'WHERE', 'GROUP BY', 'ORDER BY'],
        correctIndex: 1,
      ),
      CourseTestQuestion(
        question: 'Which JOIN keeps all rows from the left table?',
        options: ['INNER JOIN', 'RIGHT JOIN', 'LEFT JOIN', 'CROSS JOIN'],
        correctIndex: 2,
      ),
      CourseTestQuestion(
        question: 'Which function counts rows?',
        options: ['SUM()', 'COUNT()', 'LEN()', 'TOTAL()'],
        correctIndex: 1,
      ),
    ],
  ),
  Course(
    id: 'ml-foundations',
    title: 'Machine Learning Foundations',
    category: 'AI / ML',
    instructor: 'Dr. Arjun Rao',
    level: 'Intermediate',
    priceLabel: '₹199',
    rating: 4.9,
    studentsLabel: '3.4k students',
    description:
        'The core ideas behind machine learning — supervised learning, '
        'model evaluation, and where to go next.',
    lessons: [
      CourseLesson(
        id: 'ml-1',
        title: 'What is Machine Learning?',
        durationLabel: '8 min',
        content: 'Machine learning is the practice of fitting a model to data '
            'so it can make predictions on new, unseen examples — instead '
            'of hand-coding every rule.',
        keyPoints: [
          'Learn patterns from data, not hardcoded rules',
          'Supervised vs. unsupervised learning',
          'Generalization is the real goal, not memorization',
        ],
      ),
      CourseLesson(
        id: 'ml-2',
        title: 'Train / Test Split',
        durationLabel: '7 min',
        content: 'Splitting data into a training set and a held-out test set '
            'lets you measure how well a model generalizes rather than how '
            'well it memorized the training data.',
        keyPoints: [
          'Never evaluate on training data alone',
          'A common split is 80/20 train/test',
          'Validation sets help tune hyperparameters',
        ],
      ),
      CourseLesson(
        id: 'ml-3',
        title: 'Overfitting & Underfitting',
        durationLabel: '9 min',
        content: 'Overfitting means the model memorized noise in the training '
            'set and performs worse on new data. Underfitting means the '
            'model is too simple to capture the underlying pattern.',
        keyPoints: [
          'Overfitting: great on train, poor on test',
          'Underfitting: poor on both train and test',
          'Regularization and more data both help overfitting',
        ],
      ),
    ],
    finalTest: [
      CourseTestQuestion(
        question: 'What is the main goal of a machine learning model?',
        options: [
          'Memorize the training data exactly',
          'Generalize well to new, unseen data',
          'Run as fast as possible',
          'Use the largest dataset available',
        ],
        correctIndex: 1,
      ),
      CourseTestQuestion(
        question:
            'A model that performs well on training data but poorly on test data is:',
        options: [
          'Underfitting',
          'Overfitting',
          'Well-generalized',
          'Unsupervised'
        ],
        correctIndex: 1,
      ),
      CourseTestQuestion(
        question: 'Why hold out a separate test set?',
        options: [
          'To make training faster',
          'To measure generalization, not memorization',
          'It is required by Python',
          'To reduce the dataset size',
        ],
        correctIndex: 1,
      ),
    ],
  ),
  Course(
    id: 'cloud-basics',
    title: 'Cloud Computing Basics',
    category: 'Cloud',
    instructor: 'Priya Menon',
    level: 'Beginner',
    priceLabel: 'Free',
    rating: 4.5,
    studentsLabel: '760 students',
    description:
        'Understand cloud computing fundamentals — compute, storage, and '
        'the major providers — before diving into any one platform.',
    isFree: true,
    lessons: [
      CourseLesson(
        id: 'cloud-1',
        title: 'What is the Cloud?',
        durationLabel: '5 min',
        content: 'The cloud is renting compute, storage, and networking from a '
            'provider (AWS, Azure, GCP) instead of owning physical '
            'hardware — billed for what you actually use.',
        keyPoints: [
          'Pay-as-you-go compute and storage',
          'Major providers: AWS, Azure, GCP',
          'Scales up and down on demand',
        ],
      ),
      CourseLesson(
        id: 'cloud-2',
        title: 'IaaS vs PaaS vs SaaS',
        durationLabel: '6 min',
        content: 'IaaS gives you raw infrastructure (VMs, networking). PaaS '
            'manages the runtime for you and you just deploy code. SaaS is '
            'a finished product you use over the internet.',
        keyPoints: [
          'IaaS: you manage the OS and up',
          'PaaS: provider manages the runtime',
          'SaaS: fully managed end-user product',
        ],
      ),
    ],
    finalTest: [
      CourseTestQuestion(
        question: 'What best describes cloud computing?',
        options: [
          'Buying your own physical servers',
          'Renting compute/storage on demand from a provider',
          'A type of programming language',
          'A local-only backup system',
        ],
        correctIndex: 1,
      ),
      CourseTestQuestion(
        question:
            'In which model does the provider manage the runtime for you?',
        options: ['IaaS', 'PaaS', 'On-premise', 'Bare metal'],
        correctIndex: 1,
      ),
    ],
  ),
];

Course? courseById(String id) {
  for (final course in kCourseCatalog) {
    if (course.id == id) return course;
  }
  return null;
}
