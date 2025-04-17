import * as readline from 'node:readline'; // Standard Node.js readline module

const rl = readline.createInterface({
	input: process.stdin,
	output: process.stdout,
});

export default async function prompt(question: string): Promise<string> {
	return new Promise((resolve) => {
		rl.question(question, (answer) => {
			resolve(answer);
		});
	});
}
