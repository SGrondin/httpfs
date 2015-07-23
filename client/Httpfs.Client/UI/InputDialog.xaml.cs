using System;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;

namespace Httpfs.Client.UI
{
    /// <summary>
    /// Interaction logic for InputDialog.xaml
    /// </summary>
    public partial class InputDialog : Window
    {
        #region Constructors

        public InputDialog()
        {
            this.InitializeComponent();

            this.OkButton.Click += this.OkButtonOnClick;
            this.CancelButton.Click += this.CancelButtonOnClick;
            this.PreviewKeyUp += this.DialogOnPreviewKeyUp;
        }

        #endregion

        #region Properties

        private Task<string> Task { get; set; }

        #endregion

        #region Methods

        public static async Task<string> Ask(string question)
        {
            return await Ask(question, string.Empty);
        }

        public static async Task<string> Ask(string question, string title)
        {
            var dialog = new InputDialog();

            dialog.InputQuestionBlock.Text = question;
            dialog.Title = title;

            dialog.Task = new Task<string>(() => dialog.GetAnswer());

            dialog.Show();

            return await dialog.Task;
        }

        private void DialogOnPreviewKeyUp(object sender, KeyEventArgs keyEventArgs)
        {
            switch (keyEventArgs.Key)
            {
                case Key.Enter:
                    this.ResolveAndClose();
                    break;
                case Key.Escape:
                    this.Close();
                    break;
            }
        }

        private void CancelButtonOnClick(object sender, RoutedEventArgs routedEventArgs)
        {
            this.Close();
        }

        private string GetAnswer()
        {
            return this.Dispatcher.Invoke(() => this.AnswerBox.Text);
        }

        private void OkButtonOnClick(object sender, RoutedEventArgs routedEventArgs)
        {
            this.ResolveAndClose();
        }

        private void ResolveAndClose()
        {
            this.Task.Start();
            this.Close();
        }

        #endregion
    }
}