const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

const styleEndIndex = html.indexOf('</style>');

const cssToAdd = `
        @media (max-width: 768px) {
            .top-nav {
                flex-wrap: wrap;
                padding: 0.5rem 1rem;
            }
            .top-nav-links {
                overflow-x: auto;
                white-space: nowrap;
                width: 100%;
                order: 3;
                margin-top: 0.5rem;
                padding-bottom: 0.25rem;
                gap: 1rem;
            }
            .top-nav-links::-webkit-scrollbar {
                height: 4px;
            }
            .top-nav-links::-webkit-scrollbar-thumb {
                background-color: rgba(255, 255, 255, 0.2);
                border-radius: 4px;
            }
        }
`;

if (styleEndIndex !== -1) {
    html = html.substring(0, styleEndIndex) + cssToAdd + html.substring(styleEndIndex);
    fs.writeFileSync('index.html', html);
    console.log('Added CSS to index.html');
} else {
    console.log('Could not find </style> in index.html');
}
