export function ErrorMessage({ message }: { message: string }) {
  return (
    <div className="mx-auto max-w-lg rounded-md border border-red-200 bg-red-50 p-4 text-center text-red-700">
      <p className="font-medium">Something went wrong</p>
      <p className="mt-1 text-sm">{message}</p>
    </div>
  );
}
