const fs = require('fs');
const path = require('path');
require('dotenv').config();
const prisma = require('../src/config/prisma');

const outputPath = path.resolve(
  process.argv[2] || path.join(__dirname, '..', 'ml', 'data', 'reviews.csv'),
);

function csvValue(value) {
  return `"${String(value).replace(/"/g, '""')}"`;
}

async function main() {
  try {
    const reviews = await prisma.review.findMany({
      where: { comment: { not: '' } },
      select: { rating: true, comment: true },
      orderBy: { createdAt: 'asc' },
    });
    const rows = reviews.filter((review) => review.comment && review.comment.trim());
    fs.mkdirSync(path.dirname(outputPath), { recursive: true });
    fs.writeFileSync(
      outputPath,
      [
        'rating,comment',
        ...rows.map((review) => `${review.rating},${csvValue(review.comment.trim())}`),
        '',
      ].join('\n'),
      'utf8',
    );
    console.log(`Exported ${rows.length} reviews to ${outputPath}`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(`Review export failed: ${error.message}`);
  process.exitCode = 1;
});
